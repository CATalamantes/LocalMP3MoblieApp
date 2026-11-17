import 'dart:async';

import 'package:cta2000/backend/models/device_models.dart';
import 'package:cta2000/backend/services/device/device_contracts.dart';
import 'package:cta2000/backend/services/device/pairing_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/device_integration_fixture.dart';

Matcher failure(DeviceFailureKind kind) =>
    isA<DeviceFailure>().having((v) => v.kind, 'kind', kind);

void main() {
  late DeviceFixture f;
  setUp(() => f = DeviceFixture());
  tearDown(() => f.close());
  Future<void> pair() => f.pairing.pair('test-only-device', '123456');
  test(
    'verified enrollment can update settings without replacing credentials',
    () async {
      await pair();
      final secret = f.credentials.value;
      await f.pairing.updateSettings(
        DeviceSettings(
          deviceId: 'test-only-device',
          baseUri: Uri.parse('https://changed.invalid/'),
          autoReconnect: false,
        ),
      );
      expect(f.settings.value!.baseUri.host, 'changed.invalid');
      expect(f.credentials.value, same(secret));
    },
  );
  test('discovery reveals an untrusted hint and never saves records', () async {
    final found = await f.pairing.discover();
    expect(found.single.discoveryId, 'test-only-device');
    expect(f.settings.value, isNull);
    expect(f.credentials.value, isNull);
    expect(f.connections.snapshot.hardwareAuthenticated, isFalse);
  });
  for (final window in <PairingWindow?>[
    null,
    PairingWindow(open: false, expiresAt: DateTime(2100)),
    PairingWindow(open: true, expiresAt: DateTime(2000)),
  ]) {
    test(
      'unknown, closed or expired window prevents provisioning ($window)',
      () async {
        f.bonding.window = window;
        await expectLater(
          pair(),
          throwsA(failure(DeviceFailureKind.unavailable)),
        );
        expect(f.bonding.calls, 0);
        expect(f.verifier.calls, 0);
        expect(f.credentials.value, isNull);
      },
    );
  }
  test('window expiration while provisioning prevents trust commit', () async {
    var now = DateTime.utc(2026, 11, 17);
    final service = PairingService.forTesting(
      settings: f.settings,
      credentials: f.credentials,
      bondingAdapter: f.bonding,
      identityVerifier: f.verifier,
      clock: () => now,
    );
    f.bonding.window = PairingWindow(
      open: true,
      expiresAt: now.add(const Duration(minutes: 2)),
    );
    f.bonding.gate = Completer<void>();
    final assertion = expectLater(
      service.pair('test-only-device', '123456'),
      throwsA(failure(DeviceFailureKind.unavailable)),
    );
    await f.bonding.started.future;
    now = now.add(const Duration(minutes: 2));
    f.bonding.gate!.complete();
    await assertion;
    await service.close();
    expect(f.credentials.value, isNull);
  });
  test(
    'mismatched provisioned identity is rejected before verification/storage',
    () async {
      f.bonding.wrongIdentity = 'impostor';
      await expectLater(pair(), throwsA(failure(DeviceFailureKind.identity)));
      expect(f.verifier.calls, 0);
      expect(f.credentials.value, isNull);
    },
  );
  test('cancelling provisioning ignores late success and failure', () async {
    f.bonding.gate = Completer<void>();
    final assertion = expectLater(
      pair(),
      throwsA(failure(DeviceFailureKind.cancelled)),
    );
    await f.bonding.started.future;
    f.pairing.cancel();
    await assertion;
    f.bonding.gate!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(f.credentials.value, isNull);
    expect(f.settings.value, isNull);
    expect(f.verifier.calls, 0);
  });
  test(
    'forget during a secure write waits and clears the late write',
    () async {
      f.credentials.gate = Completer<void>();
      final assertion = expectLater(
        pair(),
        throwsA(failure(DeviceFailureKind.cancelled)),
      );
      await f.credentials.writing.future;
      var forgotten = false;
      final forgetting = f.pairing.forget().then((_) => forgotten = true);
      await Future<void>.delayed(Duration.zero);
      expect(forgotten, isFalse);
      f.credentials.gate!.complete();
      await assertion;
      await forgetting;
      expect(f.credentials.value, isNull);
      expect(f.settings.value, isNull);
    },
  );
  test(
    'forget during settings commit rolls back both records before returning',
    () async {
      f.settings.writeGate = Completer<void>();
      final assertion = expectLater(
        pair(),
        throwsA(failure(DeviceFailureKind.cancelled)),
      );
      await f.settings.writing.future;
      final forgetting = f.pairing.forget();
      f.settings.writeGate!.complete();
      await assertion;
      await forgetting;
      expect(f.settings.value, isNull);
      expect(f.credentials.value, isNull);
    },
  );
  test(
    'dispose during secure write drains rollback and never saves trust',
    () async {
      f.credentials.gate = Completer<void>();
      final assertion = expectLater(
        pair(),
        throwsA(failure(DeviceFailureKind.cancelled)),
      );
      await f.credentials.writing.future;
      final closing = f.pairing.close();
      f.credentials.gate!.complete();
      await assertion;
      await closing;
      expect(f.settings.value, isNull);
      expect(f.credentials.value, isNull);
    },
  );
  test(
    'cleanup failure is reported and remaining partial trust is rejected',
    () async {
      f.credentials.gate = Completer<void>();
      f.credentials.failClear = true;
      final assertion = expectLater(
        pair(),
        throwsA(failure(DeviceFailureKind.storage)),
      );
      await f.credentials.writing.future;
      final forgetting = expectLater(
        f.pairing.forget(),
        throwsA(failure(DeviceFailureKind.storage)),
      );
      f.credentials.gate!.complete();
      await assertion;
      await forgetting;
      expect(f.settings.value, isNull);
      await expectLater(
        f.pairing.loadSavedDevice(),
        throwsA(failure(DeviceFailureKind.untrusted)),
      );
    },
  );
  test(
    'cancelled discovery cannot publish devices or establish trust',
    () async {
      f.discovery.gate = Completer<void>();
      final assertion = expectLater(
        f.pairing.discover(),
        throwsA(failure(DeviceFailureKind.cancelled)),
      );
      f.pairing.cancel();
      await assertion;
      f.discovery.gate!.complete();
      expect(f.credentials.value, isNull);
    },
  );
  test(
    'configuration cannot replace identity or enable insecure endpoints',
    () async {
      f.saveTrust();
      for (final settings in [
        DeviceSettings(
          deviceId: 'other',
          baseUri: Uri.parse('https://device.invalid'),
        ),
        DeviceSettings(
          deviceId: 'test-only-device',
          baseUri: Uri.parse('http://127.0.0.1'),
        ),
      ]) {
        await expectLater(
          f.pairing.updateSettings(settings),
          throwsA(failure(DeviceFailureKind.untrusted)),
        );
      }
      expect(f.settings.value!.deviceId, 'test-only-device');
    },
  );
}
