import 'dart:async';

import 'package:cta2000/backend/controllers/controller_state.dart';
import 'package:cta2000/backend/controllers/device_controller.dart';
import 'package:cta2000/backend/services/device/device_contracts.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/device_fakes.dart';
import 'support/device_integration_fixture.dart';

Matcher controllerFailure(DeviceFailureKind kind) =>
    isA<DeviceControllerFailure>().having(
      (v) => v.deviceFailure,
      'deviceFailure',
      kind,
    );

void main() {
  late DeviceFixture f;
  setUp(() => f = DeviceFixture());
  tearDown(() => f.close());

  test(
    'a newer metadata request cancels an older connection attempt',
    () async {
      f.saveTrust();
      final gate = Completer<void>(), started = Completer<void>();
      f.wifi.onAuthenticate = (_, _) {
        started.complete();
        return gate.future;
      };
      final assertion = expectLater(
        f.controller.connect(),
        throwsA(isA<ControllerFailure>()),
      );
      await started.future;
      await f.controller.loadSavedDevice();
      gate.complete();
      await assertion;
      expect(f.controller.state.data.phase, DevicePhase.trustedDeviceSaved);
      expect(f.connections.snapshot.phase, ConnectionPhase.disconnected);
    },
  );
  test('a newer request cancels enrollment before late provisioning can save trust', () async {
    f.bonding.gate = Completer<void>();
    final assertion = expectLater(
      f.controller.pairWithCode('test-only-device', '123456'),
      throwsA(isA<ControllerFailure>()),
    );
    await f.bonding.started.future;
    await f.controller.loadSavedDevice();
    f.bonding.gate!.complete();
    await assertion;
    expect(f.settings.value, isNull);
    expect(f.credentials.value, isNull);
    expect(f.controller.state.data.phase, DevicePhase.noTrustedDevice);
  });

  test(
    'initial state has no trust, telemetry or hardware authentication',
    () async {
      expect(f.controller.state.data.phase, DevicePhase.noTrustedDevice);
      await f.controller.loadSavedDevice();
      expect(f.controller.state.status, ControllerStatus.empty);
      expect(f.controller.state.data.status, isNull);
      expect(f.controller.state.data.hardwareAuthenticated, isFalse);
    },
  );
  test('saved trust is a sanitized summary, not a connected session', () async {
    f.saveTrust();
    await f.controller.loadSavedDevice();
    expect(f.controller.state.data.phase, DevicePhase.trustedDeviceSaved);
    expect(
      f.controller.state.data.trustedDevice!.deviceId,
      testSettings.deviceId,
    );
    expect(f.controller.state.data.hardwareAuthenticated, isFalse);
    expect(f.controller.state.data.status, isNull);
  });
  test(
    'discovery and verified test enrollment never authenticate hardware',
    () async {
      await f.controller.scanForDevices();
      expect(f.controller.state.data.phase, DevicePhase.discoveredUntrusted);
      expect(f.controller.state.data.trustedDevice, isNull);
      final pending = f.controller.pairWithCode('test-only-device', '123456');
      expect(f.controller.state.data.phase, DevicePhase.pairing);
      await pending;
      expect(f.verifier.calls, 1);
      expect(f.controller.state.data.phase, DevicePhase.trustedDeviceSaved);
      await f.controller.connect();
      expect(f.controller.state.data.phase, DevicePhase.testConnected);
      expect(f.controller.state.data.hardwareAuthenticated, isFalse);
      expect(f.controller.state.data.testOnly, isTrue);
    },
  );
  test(
    'production operations remain unavailable even with stored test records',
    () async {
      final production = DeviceFixture(production: true)..saveTrust();
      try {
        await production.controller.loadSavedDevice();
        await expectLater(
          production.controller.scanForDevices(),
          throwsA(controllerFailure(DeviceFailureKind.unavailable)),
        );
        await expectLater(
          production.controller.pairWithCode('test-only-device', '123456'),
          throwsA(controllerFailure(DeviceFailureKind.unavailable)),
        );
        await expectLater(
          production.controller.connect(),
          throwsA(controllerFailure(DeviceFailureKind.unavailable)),
        );
        await expectLater(
          production.controller.refreshDeviceInfo(),
          throwsA(controllerFailure(DeviceFailureKind.unavailable)),
        );
        expect(production.controller.state.data.hardwareAuthenticated, isFalse);
        expect(production.wifi.attempts, 0);
      } finally {
        await production.close();
      }
    },
  );
  test(
    'test status exposes received capabilities and unknown telemetry as null',
    () async {
      await f.connect();
      final data = f.controller.state.data;
      expect(data.status!.testOnly, isTrue);
      expect(data.status!.batteryPercent, isNull);
      expect(data.status!.storageBytes, isNull);
      expect(data.capabilities, isNotNull);
      await f.controller.disconnect();
      expect(f.controller.state.data.phase, DevicePhase.disconnected);
      expect(f.controller.state.data.status, isNull);
      expect(f.controller.state.data.trustedDevice, isNotNull);
    },
  );
  for (final failure in [
    DeviceFailureKind.authentication,
    DeviceFailureKind.authorization,
    DeviceFailureKind.identity,
  ]) {
    test(
      '${failure.name} is terminal and metadata reload cannot clear it',
      () async {
        f.saveTrust();
        f.wifi.onAuthenticate = (_, _) async => throw DeviceFailure(failure);
        await expectLater(
          f.controller.connect(),
          throwsA(controllerFailure(failure)),
        );
        expect(f.controller.state.data.phase, DevicePhase.error);
        expect(f.wifi.attempts, 1);
        expect(f.ble.attempts, 0);
        await f.controller.loadSavedDevice();
        expect(
          (f.controller.state.error as DeviceControllerFailure).deviceFailure,
          failure,
        );
        f.wifi.onAuthenticate = (_, _) async {};
        await f.controller.connect();
        expect(f.controller.state.error, isNull);
      },
    );
  }
  test(
    'forget cancels a late successful connection and removes only local trust',
    () async {
      f.saveTrust();
      final gate = Completer<void>();
      final started = Completer<void>();
      f.wifi.onAuthenticate = (_, _) {
        started.complete();
        return gate.future;
      };
      final pending = f.controller.connect();
      final assertion = expectLater(pending, throwsA(isA<ControllerFailure>()));
      await started.future;
      await f.controller.forgetDevice();
      gate.complete();
      await assertion;
      expect(f.settings.value, isNull);
      expect(f.credentials.value, isNull);
      expect(f.controller.state.data.phase, DevicePhase.noTrustedDevice);
      expect(f.controller.state.data.trustedDevice, isNull);
      expect(f.controller.state.data.hardwareAuthenticated, isFalse);
    },
  );
  test(
    'late status response cannot repopulate forgotten device telemetry',
    () async {
      await f.connect();
      final gate = Completer<Object?>();
      final started = Completer<Map<String, Object?>>();
      f.wifi.onSend = (_, request, _) {
        started.complete(request);
        return gate.future;
      };
      final assertion = expectLater(
        f.controller.refreshDeviceInfo(),
        throwsA(isA<ControllerFailure>()),
      );
      final request = await started.future;
      await f.controller.forgetDevice();
      gate.complete(
        ProtocolTransport.response(request, {
          'device_id': 'test-only-device',
          'capabilities': {'operations': []},
        }),
      );
      await assertion;
      expect(f.controller.state.data.status, isNull);
      expect(f.controller.state.data.phase, DevicePhase.noTrustedDevice);
    },
  );
  test('older failed read cannot replace a newer controller request', () async {
    f.saveTrust();
    final gate = Completer<void>();
    f.settings.readGate = gate;
    final assertion = expectLater(
      f.controller.loadSavedDevice(),
      throwsA(isA<ControllerFailure>()),
    );
    await Future<void>.delayed(Duration.zero);
    f.settings.readGate = null;
    await f.controller.forgetDevice();
    gate.complete();
    await assertion;
    expect(f.controller.state.data.trustedDevice, isNull);
    expect(f.controller.state.error, isNull);
  });
  test(
    'configuration change cancels authentication and preserves saved identity',
    () async {
      f.saveTrust();
      final gate = Completer<void>();
      final started = Completer<void>();
      f.wifi.onAuthenticate = (_, _) {
        started.complete();
        return gate.future;
      };
      final assertion = expectLater(
        f.controller.connect(),
        throwsA(isA<ControllerFailure>()),
      );
      await started.future;
      await f.controller.updateConnectionSettings(
        DeviceSettings(
          deviceId: testSettings.deviceId,
          baseUri: Uri.parse('https://new-endpoint.invalid/'),
          autoReconnect: false,
        ),
      );
      gate.complete();
      await assertion;
      expect(f.settings.value!.baseUri.host, 'new-endpoint.invalid');
      expect(f.credentials.value, same(testCredentials));
      expect(f.controller.state.data.phase, DevicePhase.trustedDeviceSaved);
    },
  );
  test(
    'disposing during authentication produces no late notification',
    () async {
      f.saveTrust();
      final gate = Completer<void>();
      final started = Completer<void>();
      f.wifi.onAuthenticate = (_, _) {
        started.complete();
        return gate.future;
      };
      var notifications = 0;
      f.controller.addListener(() => notifications++);
      final assertion = expectLater(
        f.controller.connect(),
        throwsA(isA<ControllerFailure>()),
      );
      await started.future;
      await f.controller.close();
      final count = notifications;
      gate.complete();
      await assertion;
      expect(notifications, count);
      expect(f.controller.state.data.hardwareAuthenticated, isFalse);
    },
  );
  test('headphone selection remains explicitly unsupported', () async {
    await expectLater(
      f.controller.selectHeadphones('test-accessory'),
      throwsA(controllerFailure(DeviceFailureKind.unsupported)),
    );
    expect(f.wifi.sends, 0);
  });
}
