import 'dart:async';

import 'package:cta2000/backend/services/device/device_contracts.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/device_fakes.dart';
import 'support/device_integration_fixture.dart';

void main() {
  late DeviceFixture f;
  setUp(() => f = DeviceFixture());
  tearDown(() => f.close());

  test(
    'transient recovery retains exactly the approved retry delays',
    () async {
      f.saveTrust();
      f.wifi.onAuthenticate = (attempt, _) async {
        if (attempt < 4) throw const DeviceFailure(DeviceFailureKind.transient);
      };
      await f.connections.reconnect();
      expect(f.wifi.attempts, 4);
      expect(f.delays.map((v) => v.inSeconds), [1, 2, 4]);
      expect(f.connections.snapshot.phase, ConnectionPhase.authenticated);
      expect(f.connections.snapshot.hardwareAuthenticated, isFalse);
    },
  );
  test(
    'trust removed during retry wait stops before another attempt',
    () async {
      await f.close();
      final gate = Completer<void>(), waiting = Completer<void>();
      f = DeviceFixture(
        waitForRetry: (_, _) {
          waiting.complete();
          return gate.future;
        },
      )..saveTrust();
      f.wifi.onAuthenticate = (_, _) async =>
          throw const DeviceFailure(DeviceFailureKind.transient);
      final pending = f.connections.reconnect();
      await waiting.future;
      f.settings.value = null;
      f.credentials.value = null;
      gate.complete();
      await pending;
      expect(f.wifi.attempts, 1);
      expect(f.connections.snapshot.phase, ConnectionPhase.disconnected);
    },
  );
  test(
    'endpoint changes during authentication cannot establish the old session',
    () async {
      f.saveTrust();
      final gate = Completer<void>(), started = Completer<void>();
      f.wifi.onAuthenticate = (_, _) {
        started.complete();
        return gate.future;
      };
      final pending = f.connections.reconnect();
      await started.future;
      f.settings.value = DeviceSettings(
        deviceId: testSettings.deviceId,
        baseUri: Uri.parse('https://new.invalid/'),
      );
      gate.complete();
      await pending;
      expect(f.connections.snapshot.phase, ConnectionPhase.disconnected);
      expect(f.wifi.disconnects, greaterThanOrEqualTo(1));
    },
  );
  test(
    'changed credentials block command submission and invalidate the session',
    () async {
      await f.connect();
      final before = f.wifi.sends;
      f.credentials.value = null;
      await expectLater(
        f.client.pause(),
        throwsA(
          isA<DeviceFailure>().having(
            (v) => v.kind,
            'kind',
            DeviceFailureKind.untrusted,
          ),
        ),
      );
      expect(f.wifi.sends, before);
      expect(f.connections.snapshot.phase, ConnectionPhase.disconnected);
    },
  );
  test(
    'a hung command times out once, cancels its adapter, and never retries',
    () async {
      await f.connect();
      fakeAsync((clock) {
        var cancelled = false;
        f.wifi.onSend = (_, _, cancellation) {
          cancellation.cancelled.then((_) => cancelled = true);
          return Completer<Object?>().future;
        };
        DeviceFailure? failed;
        f.connections
            .send('pause', payload: {}, timeout: const Duration(seconds: 2))
            .catchError((Object error) {
              failed = error as DeviceFailure;
              return null;
            });
        clock.flushMicrotasks();
        expect(f.wifi.sends, 2);
        clock.elapse(const Duration(seconds: 2));
        expect(failed!.kind, DeviceFailureKind.transient);
        expect(cancelled, isTrue);
        clock.elapse(const Duration(seconds: 20));
        expect(f.wifi.sends, 2);
      });
    },
  );
}
