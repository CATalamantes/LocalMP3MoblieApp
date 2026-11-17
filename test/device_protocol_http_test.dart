// Real loopback HTTP validates proposed JSON, not device commands/authentication.
import 'dart:convert';
import 'dart:io';

import 'package:cta2000/backend/models/device_models.dart';
import 'package:cta2000/backend/services/device/device_contracts.dart';
import 'package:cta2000/backend/services/device/device_protocol.dart';
import 'package:cta2000/backend/services/device/json_http_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late JsonHttpClient client;
  late List<Future<void>> handlers;
  var requests = 0;
  setUp(() async {
    requests = 0;
    handlers = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      handlers.add(() async {
        try {
          requests++;
          expect(request.headers.value('authorization'), isNull);
          expect(request.headers.value('cookie'), isNull);
          final path = request.uri.path;
          if (path.endsWith('/interrupt')) {
            (await request.response.detachSocket()).destroy();
            return;
          }
          if (path.endsWith('/slow')) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          final status = int.tryParse(path.split('/').last);
          if (status != null) {
            request.response.statusCode = status;
            request.response.write('{"testOnly":true}');
          } else if (path.endsWith('/invalid')) {
            request.response.write('{bad');
          } else if (request.method == 'GET') {
            request.response.write(
              jsonEncode({'testOnly': true, 'hardwareAuthenticated': false}),
            );
          } else {
            // Validate nested candidate data. Never interpret or execute its operation.
            final body =
                jsonDecode(await utf8.decoder.bind(request).join()) as Map;
            final candidate = DeviceProtocol.validateCandidate(
              body['candidate'],
            );
            request.response.write(
              jsonEncode({
                'testOnly': true,
                'hardwareAuthenticated': false,
                'candidate': candidate,
              }),
            );
          }
          await request.response.close();
        } catch (_) {
          /* Cancellation may close the response socket. */
        }
      }());
    });
    client = JsonHttpClient(
      configuration: HttpConfiguration(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}/fixture/'),
        localDevelopment: true,
      ),
    );
  });
  tearDown(() async {
    client.close();
    await server.close(force: true);
    await Future.wait(handlers);
  });
  Future<Object?> validation(DeviceOperation operation) => client.request(
    'POST',
    'validate',
    body: {'candidate': DeviceProtocol.request('fixture-1', operation, {})},
  );

  test('GET and POST use actual HTTP without trusting the fixture', () async {
    final reachable = await client.request('GET', 'health') as Map;
    expect(reachable['hardwareAuthenticated'], isFalse);
    for (final operation in DeviceOperation.values) {
      final response = await validation(operation) as Map;
      final candidate = response['candidate'] as Map;
      expect(candidate['operation'], operation.name);
      expect(candidate['request_id'], 'fixture-1');
      expect(response['testOnly'], isTrue);
      expect(response['hardwareAuthenticated'], isFalse);
    }
    expect(requests, DeviceOperation.values.length + 1);
  });
  for (final entry in {
    401: DeviceFailureKind.authentication,
    403: DeviceFailureKind.authorization,
    404: DeviceFailureKind.unavailable,
    501: DeviceFailureKind.unsupported,
    503: DeviceFailureKind.transient,
  }.entries) {
    test('real HTTP ${entry.key} maps distinctly without retry', () async {
      try {
        await client.request('GET', '${entry.key}');
        fail('Expected failure');
      } on NetworkFailure catch (failure) {
        expect(DeviceProtocol.fromNetwork(failure).kind, entry.value);
      }
      expect(requests, 1);
    });
  }
  test(
    'invalid JSON and missing/incorrect response fields fail closed',
    () async {
      await expectLater(
        client.request('GET', 'invalid'),
        throwsA(
          isA<NetworkFailure>().having(
            (v) => DeviceProtocol.fromNetwork(v).kind,
            'mapped kind',
            DeviceFailureKind.protocol,
          ),
        ),
      );
      for (final raw in <Object?>[
        {},
        {'protocol_version': 1, 'request_id': 'a'},
        {'protocol_version': 1, 'request_id': 'a', 'result': {}, 'error': {}},
        {'protocol_version': 1, 'request_id': 'wrong', 'result': {}},
        [],
      ]) {
        expect(
          () => DeviceProtocol.response(raw, 'a'),
          throwsA(isA<DeviceFailure>()),
        );
      }
    },
  );
  test(
    'typed parsers reject malformed telemetry while preserving unknown values',
    () {
      const empty = {
        'device_id': 'test',
        'capabilities': {'operations': <String>[]},
      };
      final status = DeviceProtocol.status(
        empty,
        expectedDeviceId: 'test',
        testOnly: true,
      );
      expect(status.batteryPercent, isNull);
      expect(status.charging, isNull);
      for (final fields in <Map<String, Object?>>[
        {'battery_percent': 101},
        {'battery_percent': '50'},
        {'charging': 'yes'},
        {'storage_bytes': 5, 'free_bytes': 6},
        {'storage_bytes': -1},
        {'capabilities': {}},
        {'firmware_version': ''},
      ]) {
        expect(
          () => DeviceProtocol.status(
            {...empty, ...fields},
            expectedDeviceId: 'test',
            testOnly: true,
          ),
          throwsA(isA<DeviceFailure>()),
        );
      }
      expect(
        () => DeviceProtocol.playback({
          'phase': 'playing',
          'position_ms': 3,
          'duration_ms': 2,
        }, testOnly: true),
        throwsA(isA<DeviceFailure>()),
      );
      expect(
        () => DeviceProtocol.recording({'phase': 'invented'}, testOnly: true),
        throwsA(isA<DeviceFailure>()),
      );
      expect(
        () => DeviceProtocol.files({
          'files': [{}],
        }, testOnly: true),
        throwsA(isA<DeviceFailure>()),
      );
      expect(
        () => DeviceProtocol.download({'phase': 'queued'}, testOnly: true),
        throwsA(isA<DeviceFailure>()),
      );
    },
  );
  test(
    'wire errors are sanitized and candidate operations are allowlisted',
    () {
      final raw = {
        'protocol_version': 1,
        'request_id': 'a',
        'error': {'code': 'forbidden', 'message': 'DO-NOT-LOG-THIS'},
      };
      try {
        DeviceProtocol.response(raw, 'a');
        fail('Expected failure');
      } on DeviceFailure catch (failure) {
        expect(failure.kind, DeviceFailureKind.authorization);
        expect(failure.toString(), isNot(contains('DO-NOT-LOG-THIS')));
      }
      expect(
        () => DeviceProtocol.validateCandidate({
          'protocol_version': 1,
          'request_id': 'a',
          'operation': 'shell',
          'payload': {},
        }),
        throwsA(isA<DeviceFailure>()),
      );
      expect(
        () => DeviceProtocol.capabilities({
          'operations': [42],
        }),
        throwsA(isA<DeviceFailure>()),
      );
    },
  );
  test(
    'timeout, cancellation and interrupted HTTP fail without replay',
    () async {
      await expectLater(
        client.request(
          'GET',
          'slow',
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(
          isA<NetworkFailure>().having(
            (v) => v.kind,
            'kind',
            NetworkFailureKind.timeout,
          ),
        ),
      );
      final token = RequestCancellation();
      final pending = expectLater(
        client.request('GET', 'slow', cancellation: token),
        throwsA(
          isA<NetworkFailure>().having(
            (v) => v.kind,
            'kind',
            NetworkFailureKind.cancelled,
          ),
        ),
      );
      token.cancel();
      await pending;
      await expectLater(
        client.request('GET', 'interrupt'),
        throwsA(
          isA<NetworkFailure>().having(
            (v) => v.kind,
            'kind',
            NetworkFailureKind.transport,
          ),
        ),
      );
      expect(requests, lessThanOrEqualTo(3));
    },
  );
  test(
    'insecure credential transmission is rejected before server receives it',
    () async {
      await expectLater(
        client.request(
          'POST',
          'validate',
          headers: {'Authorization': 'test-secret'},
        ),
        throwsA(isA<NetworkFailure>()),
      );
      expect(requests, 0);
    },
  );
}
