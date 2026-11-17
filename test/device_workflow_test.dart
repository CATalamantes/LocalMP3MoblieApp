import 'dart:async';

import 'package:cta2000/backend/services/device/connection_manager.dart';
import 'package:cta2000/backend/services/device/device_contracts.dart';
import 'package:cta2000/backend/services/device/pairing_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/device_fakes.dart';

Matcher deviceFailure(DeviceFailureKind kind) =>
    isA<DeviceFailure>().having((e) => e.kind, 'kind', kind);

void main() {
  late MemorySettings settings;
  late MemoryCredentials credentials;
  late FakeProvisioning bonding;
  late FakeVerifier verifier;
  late FakeTransport wifi, ble;
  late PairingService pairing;
  late ConnectionManager connections;

  setUp(() {
    settings = MemorySettings();
    credentials = MemoryCredentials();
    bonding = FakeProvisioning();
    verifier = FakeVerifier();
    wifi = FakeTransport(TransportKind.wifi);
    ble = FakeTransport(TransportKind.ble);
    pairing = PairingService.forTesting(
      settings: settings,
      credentials: credentials,
      bondingAdapter: bonding,
      identityVerifier: verifier,
      disconnect: () => connections.disconnect(),
    );
    connections = ConnectionManager.forTesting(
      settings: settings,
      credentials: credentials,
      wifiTransport: wifi,
      bleTransport: ble,
    );
  });
  tearDown(() => connections.dispose());

  Future<void> pair() => pairing.pair('test-only-device', '123456');

  test(
    'production cannot pair or authenticate even with saved test credentials',
    () async {
      await pair();
      final productionPairing = PairingService.production(
        settings: settings,
        credentials: credentials,
      );
      final production = ConnectionManager.production(
        settings: settings,
        credentials: credentials,
      );
      try {
        await expectLater(
          productionPairing.pair('test-only-device', '123456'),
          throwsA(deviceFailure(DeviceFailureKind.unavailable)),
        );
        await production.reconnect();
        expect(production.snapshot.phase, ConnectionPhase.unavailable);
        expect(production.snapshot.hardwareAuthenticated, isFalse);
        expect(wifi.attempts, 0);
        expect(bonding.calls, 1);
        await expectLater(
          production.send('status'),
          throwsA(deviceFailure(DeviceFailureKind.unavailable)),
        );
      } finally {
        production.dispose();
      }
    },
  );

  test(
    'test pairing saves verified trust, restores it and enforces one device',
    () async {
      await pair();
      expect(pairing.testOnly, isTrue);
      expect(verifier.calls, 1);
      expect(settings.value!.toMap().keys, isNot(contains('credential')));
      expect(credentials.value!.deviceId, settings.value!.deviceId);
      expect(
        DeviceSettings.fromMap(settings.value!.toMap()).toMap(),
        settings.value!.toMap(),
      );
      expect(
        DeviceCredentials.fromMap(credentials.value!.toMap()).toMap(),
        credentials.value!.toMap(),
      );
      await expectLater(
        pairing.pair('other', '123456'),
        throwsA(deviceFailure(DeviceFailureKind.untrusted)),
      );
      expect(bonding.calls, 1);
      await connections.reconnect();
      expect(connections.snapshot.phase, ConnectionPhase.authenticated);
      expect(connections.snapshot.testOnly, isTrue);
      expect(connections.snapshot.hardwareAuthenticated, isFalse);
      expect(connections.snapshot.transport, TransportKind.wifi);
      expect(wifi.attempts, 1);
      expect(ble.attempts, 0);
      expect(await connections.send('status'), {'testOnly': true});
    },
  );

  test(
    'forget still clears credentials when another cleanup operation fails',
    () async {
      await pair();
      settings.failClear = true;
      await expectLater(
        pairing.forget(),
        throwsA(deviceFailure(DeviceFailureKind.storage)),
      );
      expect(credentials.value, isNull);
      await connections.reconnect();
      expect(connections.snapshot.failure, DeviceFailureKind.untrusted);
    },
  );

  test('invalid passkeys and rejected verification save no trust', () async {
    await expectLater(
      pairing.pair('test-only-device', '12'),
      throwsA(deviceFailure(DeviceFailureKind.authorization)),
    );
    expect(bonding.calls, 0);
    for (final failure in [
      DeviceFailureKind.identity,
      DeviceFailureKind.authorization,
    ]) {
      verifier.failure = failure;
      await expectLater(pair(), throwsA(deviceFailure(failure)));
      expect(settings.value, isNull);
      expect(credentials.value, isNull);
    }
    verifier.failure = null;
    bonding.failure = DeviceFailureKind.unavailable;
    await expectLater(
      pair(),
      throwsA(deviceFailure(DeviceFailureKind.unavailable)),
    );
    expect(settings.value, isNull);
  });

  test(
    'partial settings or credential storage failures clean up trust',
    () async {
      settings.failWrite = true;
      await expectLater(
        pair(),
        throwsA(deviceFailure(DeviceFailureKind.storage)),
      );
      expect(settings.value, isNull);
      expect(credentials.value, isNull);
      settings.failWrite = false;
      credentials.failWrite = true;
      await expectLater(
        pair(),
        throwsA(deviceFailure(DeviceFailureKind.storage)),
      );
      expect(settings.value, isNull);
      expect(credentials.value, isNull);
    },
  );

  test(
    'forget clears local records and reconnect no longer tries a device',
    () async {
      await pair();
      await connections.reconnect();
      await connections.disconnect();
      await pairing.forget();
      expect(settings.value, isNull);
      expect(credentials.value, isNull);
      await connections.reconnect();
      expect(connections.snapshot.phase, ConnectionPhase.disconnected);
      expect(wifi.attempts, 1);
    },
  );

  test(
    'missing, mismatched or disabled trust never authenticates automatically',
    () async {
      await connections.reconnect();
      expect(connections.snapshot.phase, ConnectionPhase.disconnected);
      settings.value = testSettings;
      await connections.reconnect();
      expect(connections.snapshot.failure, DeviceFailureKind.untrusted);
      credentials.value = const DeviceCredentials(
        deviceId: 'other',
        credential: 'x',
        pinnedIdentity: 'x',
      );
      await connections.reconnect();
      expect(connections.snapshot.failure, DeviceFailureKind.untrusted);
      credentials.value = testCredentials;
      settings.value = DeviceSettings(
        deviceId: testSettings.deviceId,
        baseUri: testSettings.baseUri,
        autoReconnect: false,
      );
      await connections.reconnect();
      expect(wifi.attempts, 0);
      await connections.reconnect(automatic: false);
      expect(wifi.attempts, 1);
    },
  );

  test(
    'one initial attempt plus three retries at exactly 1, 2 and 4 seconds',
    () {
      fakeAsync((clock) {
        settings.value = testSettings;
        credentials.value = testCredentials;
        wifi.onAuthenticate = (_, _) async =>
            throw const DeviceFailure(DeviceFailureKind.transient);
        var completed = false;
        connections.reconnect().then((_) => completed = true);
        clock.flushMicrotasks();
        expect(wifi.attempts, 1);
        clock.elapse(const Duration(milliseconds: 999));
        expect(wifi.attempts, 1);
        clock.elapse(const Duration(milliseconds: 1));
        expect(wifi.attempts, 2);
        clock.elapse(const Duration(milliseconds: 1999));
        expect(wifi.attempts, 2);
        clock.elapse(const Duration(milliseconds: 1));
        expect(wifi.attempts, 3);
        clock.elapse(const Duration(seconds: 4));
        expect(wifi.attempts, 4);
        expect(completed, isTrue);
        expect(connections.snapshot.phase, ConnectionPhase.failed);
        clock.elapse(const Duration(minutes: 1));
        expect(wifi.attempts, 4);
      });
    },
  );

  test('fallback only for supported BLE commands, never identity or authorization errors', () async {
    await pair();
    for (final failure in [
      DeviceFailureKind.identity,
      DeviceFailureKind.authorization,
    ]) {
      wifi.onAuthenticate = (_, _) async => throw DeviceFailure(failure);
      await connections.reconnect(operation: 'status');
      expect(connections.snapshot.failure, failure);
      expect(ble.attempts, 0);
    }
    wifi.onAuthenticate = (_, _) async =>
        throw const DeviceFailure(DeviceFailureKind.transient);
    await connections.reconnect(operation: 'status');
    expect(connections.snapshot.transport, TransportKind.ble);
    await expectLater(
      connections.send('status', largeTransfer: true),
      throwsA(deviceFailure(DeviceFailureKind.unsupported)),
    );
    await expectLater(
      connections.send('unknown'),
      throwsA(deviceFailure(DeviceFailureKind.unsupported)),
    );
  });

  test(
    'large transfers and unsupported commands never fall back to BLE',
    () async {
      await pair();
      final delays = <Duration>[];
      connections.dispose();
      connections = ConnectionManager.forTesting(
        settings: settings,
        credentials: credentials,
        wifiTransport: wifi,
        bleTransport: ble,
        waitForRetry: (delay, _) async {
          delays.add(delay);
        },
      );
      wifi.onAuthenticate = (_, _) async =>
          throw const DeviceFailure(DeviceFailureKind.transient);
      await connections.reconnect(operation: 'status', largeTransfer: true);
      expect(ble.attempts, 0);
      expect(wifi.attempts, 4);
      expect(delays.map((d) => d.inSeconds), [1, 2, 4]);
      await connections.reconnect(operation: 'unknown');
      expect(ble.attempts, 0);
    },
  );

  test('commands are sent once and are never retried', () async {
    await pair();
    await connections.reconnect();
    wifi.sendFailure = DeviceFailureKind.transient;
    await expectLater(
      connections.send('status'),
      throwsA(deviceFailure(DeviceFailureKind.transient)),
    );
    expect(wifi.sends, 1);
  });

  test(
    'disconnect and superseding reconnect ignore late authentication',
    () async {
      await pair();
      final late = Completer<void>();
      wifi.onAuthenticate = (_, _) => late.future;
      final pending = connections.reconnect();
      await Future<void>.delayed(Duration.zero);
      await connections.disconnect();
      late.complete();
      await pending;
      expect(connections.snapshot.phase, ConnectionPhase.disconnected);
      expect(connections.snapshot.hardwareAuthenticated, isFalse);

      final older = Completer<void>();
      wifi.onAuthenticate = (_, _) => older.future;
      final superseded = connections.reconnect();
      await Future<void>.delayed(Duration.zero);
      wifi.onAuthenticate = (_, _) async {};
      await connections.reconnect();
      older.completeError(const DeviceFailure(DeviceFailureKind.identity));
      await superseded;
      expect(connections.snapshot.phase, ConnectionPhase.authenticated);
      expect(connections.snapshot.testOnly, isTrue);
    },
  );

  test('dispose cancels pending reconnect delays without further attempts', () {
    fakeAsync((clock) {
      settings.value = testSettings;
      credentials.value = testCredentials;
      wifi.onAuthenticate = (_, _) async =>
          throw const DeviceFailure(DeviceFailureKind.transient);
      connections.reconnect();
      clock.flushMicrotasks();
      expect(wifi.attempts, 1);
      connections.dispose();
      // Avoid a second dispose in tearDown.
      connections = ConnectionManager.production(
        settings: settings,
        credentials: credentials,
      );
      clock.elapse(const Duration(seconds: 10));
      expect(wifi.attempts, 1);
    });
  });
}
