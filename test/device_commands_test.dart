import 'dart:async';

import 'package:cta2000/backend/models/device_models.dart';
import 'package:cta2000/backend/services/device/device_contracts.dart';
import 'package:cta2000/backend/services/device/json_http_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/device_integration_fixture.dart';

Matcher failure(DeviceFailureKind kind) =>
    isA<DeviceFailure>().having((v) => v.kind, 'kind', kind);

void main() {
  late DeviceFixture f;
  setUp(() => f = DeviceFixture());
  tearDown(() => f.close());

  test(
    'older status cannot widen newer capability results in the same session',
    () async {
      await f.connect();
      final gate = Completer<Object?>();
      final started = Completer<Map<String, Object?>>();
      f.wifi.onSend = (operation, request, _) async {
        if (operation == 'status') {
          started.complete(request);
          return gate.future;
        }
        return ProtocolTransport.response(request, {'operations': <String>[]});
      };
      final assertion = expectLater(
        f.client.requestStatus(),
        throwsA(failure(DeviceFailureKind.cancelled)),
      );
      final old = await started.future;
      await f.client.readCapabilities();
      gate.complete(
        ProtocolTransport.response(old, {
          'device_id': 'test-only-device',
          'capabilities': {
            'operations': ['play'],
          },
        }),
      );
      await assertion;
      expect(f.client.capabilities!.operations, isEmpty);
      await expectLater(
        f.client.play(),
        throwsA(failure(DeviceFailureKind.unsupported)),
      );
    },
  );

  test('commands require authentication and production cannot consume a test session', () async {
    await expectLater(
      f.client.play(),
      throwsA(failure(DeviceFailureKind.unavailable)),
    );
    final production = DeviceFixture(productionClient: true)..saveTrust();
    try {
      await production.connections.reconnect();
      await expectLater(
        production.client.requestStatus(),
        throwsA(failure(DeviceFailureKind.unavailable)),
      );
      expect(production.wifi.sends, 0);
      expect(production.connections.snapshot.hardwareAuthenticated, isFalse);
    } finally {
      await production.close();
    }
  });
  test('unknown capabilities block commands, then received capabilities allow routing', () async {
    f.saveTrust();
    await f.connections.reconnect();
    await expectLater(
      f.client.play(),
      throwsA(failure(DeviceFailureKind.unsupported)),
    );
    await f.client.readCapabilities();
    await f.client.play(songId: 'remote-song');
    expect(f.wifi.requests.last['operation'], 'play');
    expect(f.wifi.requests.last['payload'], {'song_id': 'remote-song'});
  });
  test(
    'typed playback and recording controls route once with validated results',
    () async {
      await f.connect();
      await f.client.play();
      await f.client.pause();
      await f.client.resume();
      await f.client.stop();
      await f.client.next();
      await f.client.previous();
      await f.client.seek(const Duration(milliseconds: 750));
      final playback = await f.client.readPlaybackState();
      expect(playback.position, const Duration(milliseconds: 500));
      expect(playback.duration, const Duration(seconds: 1));
      expect(playback.songId, 'remote-test');
      expect(playback.testOnly, isTrue);
      await f.client.startRecording();
      await f.client.stopRecording();
      expect(
        (await f.client.readRecordingState()).phase,
        RemoteRecordingPhase.idle,
      );
      expect(
        (await f.client.readRecordingMetadata('r-test')).recordingId,
        'r-test',
      );
      expect(
        f.wifi.requests.map((v) => v['request_id']).toSet().length,
        f.wifi.sends,
      );
      expect(f.wifi.requests.where((v) => v['operation'] == 'play').length, 1);
    },
  );
  test(
    'file and download contracts route IDs and URLs without local file access',
    () async {
      await f.connect();
      final files = await f.client.listFiles();
      expect(files.single.fileId, 'file-test');
      expect(files.single.testOnly, isTrue);
      await f.client.removeFile(files.single.fileId);
      final job = await f.client.requestDownload(
        Uri.parse('https://example.invalid/owned-audio'),
      );
      expect(job.phase, DownloadPhase.queued);
      expect(
        (await f.client.readDownloadStatus(job.jobId)).phase,
        DownloadPhase.running,
      );
      expect(f.wifi.requests.last['payload'], {'job_id': 'job-test'});
    },
  );
  test('invalid arguments are rejected before any command is sent', () async {
    await f.connect();
    final before = f.wifi.sends;
    expect(
      () => f.client.seek(const Duration(seconds: -1)),
      throwsA(failure(DeviceFailureKind.invalidInput)),
    );
    expect(
      () => f.client.play(songId: ''),
      throwsA(failure(DeviceFailureKind.invalidInput)),
    );
    await expectLater(
      f.client.requestDownload(Uri.parse('file:///no-shell')),
      throwsA(failure(DeviceFailureKind.invalidInput)),
    );
    await expectLater(
      f.client.readDownloadStatus(''),
      throwsA(failure(DeviceFailureKind.invalidInput)),
    );
    expect(f.wifi.sends, before);
  });
  test('capabilities and transport support both gate commands', () async {
    f.wifi.operations.remove('play');
    await f.connect();
    await expectLater(
      f.client.play(),
      throwsA(failure(DeviceFailureKind.unsupported)),
    );
    f.wifi.operations.remove('stop');
    await expectLater(
      f.client.stop(),
      throwsA(failure(DeviceFailureKind.unsupported)),
    );
    expect(f.wifi.sends, 1);
  });
  test(
    'lost state-changing response is uncertain and is never replayed',
    () async {
      await f.connect();
      f.wifi.onSend = (_, _, _) async =>
          throw const NetworkFailure(NetworkFailureKind.timeout);
      await expectLater(
        f.client.next(),
        throwsA(
          isA<DeviceCommandFailure>().having(
            (v) => v.outcomeUnknown,
            'outcomeUnknown',
            isTrue,
          ),
        ),
      );
      expect(f.wifi.sends, 2);
      expect(f.wifi.attempts, 1);
    },
  );
  test('mismatched response IDs, versions, missing fields and acknowledgements fail', () async {
    await f.connect();
    for (final result in <Object?>[
      {},
      {'accepted': false},
      null,
    ]) {
      f.wifi.onSend = (_, request, _) async =>
          ProtocolTransport.response(request, result);
      await expectLater(
        f.client.pause(),
        throwsA(failure(DeviceFailureKind.protocol)),
      );
    }
    f.wifi.onSend = (_, request, _) async => {
      'protocol_version': 1,
      'request_id': 'wrong',
      'result': {'accepted': true},
    };
    await expectLater(
      f.client.pause(),
      throwsA(failure(DeviceFailureKind.protocol)),
    );
    f.wifi.onSend = (_, request, _) async => {
      'protocol_version': 2,
      'request_id': request['request_id'],
      'result': {},
    };
    await expectLater(
      f.client.readPlaybackState(),
      throwsA(failure(DeviceFailureKind.protocol)),
    );
  });
  test('authenticated status identity mismatch rejects the session', () async {
    await f.connect();
    f.wifi.onSend = (_, request, _) async =>
        ProtocolTransport.response(request, {
          'device_id': 'wrong',
          'capabilities': {'operations': []},
        });
    await expectLater(
      f.client.requestStatus(),
      throwsA(failure(DeviceFailureKind.identity)),
    );
    expect(f.connections.snapshot.failure, DeviceFailureKind.identity);
    expect(f.client.capabilities, isNull);
    await expectLater(
      f.client.play(),
      throwsA(failure(DeviceFailureKind.unavailable)),
    );
  });
  for (final entry in {
    401: DeviceFailureKind.authentication,
    403: DeviceFailureKind.authorization,
  }.entries) {
    test(
      'HTTP ${entry.key} rejects session without fallback or retry',
      () async {
        await f.connect();
        f.wifi.onSend = (_, _, _) async => throw NetworkFailure(
          NetworkFailureKind.response,
          statusCode: entry.key,
        );
        await expectLater(f.client.pause(), throwsA(failure(entry.value)));
        expect(f.connections.snapshot.failure, entry.value);
        expect(f.ble.attempts, 0);
        expect(f.wifi.sends, 2);
        expect(f.controller.state.error, isNotNull);
      },
    );
  }
  test(
    'old rejected response cannot invalidate a newer verified test session',
    () async {
      await f.connect();
      final old = Completer<Object?>();
      final started = Completer<void>();
      f.wifi.onSend = (_, _, _) {
        started.complete();
        return old.future;
      };
      final assertion = expectLater(
        f.client.pause(),
        throwsA(failure(DeviceFailureKind.cancelled)),
      );
      await started.future;
      await f.connections.reconnect();
      old.completeError(
        const NetworkFailure(NetworkFailureKind.response, statusCode: 401),
      );
      await assertion;
      await Future<void>.delayed(Duration.zero);
      expect(f.connections.snapshot.phase, ConnectionPhase.authenticated);
      expect(f.connections.snapshot.failure, isNull);
    },
  );
  test(
    'transfer contracts are unavailable on Wi-Fi and rejected on BLE',
    () async {
      await f.connect();
      await expectLater(
        f.client.uploadAudio(
          Uri.parse('file:///not-read.mp3'),
          remoteName: 'owned.mp3',
        ),
        throwsA(failure(DeviceFailureKind.unavailable)),
      );
      await expectLater(
        f.client.downloadRecording(
          'remote',
          destination: Uri.parse('file:///not-written.mp3'),
        ),
        throwsA(failure(DeviceFailureKind.unavailable)),
      );
      f.wifi.onAuthenticate = (_, _) async =>
          throw const DeviceFailure(DeviceFailureKind.transient);
      await f.connections.reconnect(operation: 'status');
      await f.client.requestStatus();
      expect(f.connections.snapshot.transport, TransportKind.ble);
      await expectLater(
        f.client.uploadAudio(
          Uri.parse('file:///not-read.mp3'),
          remoteName: 'owned.mp3',
        ),
        throwsA(failure(DeviceFailureKind.unsupported)),
      );
      expect(f.ble.requests.length, 1);
    },
  );
  test(
    'client disposal cancels an in-flight command and ignores its completion',
    () async {
      await f.connect();
      final gate = Completer<Object?>();
      final started = Completer<Map<String, Object?>>();
      f.wifi.onSend = (_, request, _) {
        started.complete(request);
        return gate.future;
      };
      final assertion = expectLater(
        f.client.pause(),
        throwsA(failure(DeviceFailureKind.cancelled)),
      );
      final request = await started.future;
      f.client.dispose();
      await assertion;
      gate.complete(ProtocolTransport.response(request, {'accepted': true}));
      expect(f.client.capabilities, isNull);
    },
  );
}
