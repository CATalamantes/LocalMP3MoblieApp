import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cta2000/backend/services/device/json_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

TypeMatcher<NetworkFailure> failure(NetworkFailureKind kind) =>
    isA<NetworkFailure>().having((e) => e.kind, 'kind', kind);

class RecordingClient extends http.BaseClient {
  final inner = http.Client();
  bool aborted = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request is http.Abortable) {
      request.abortTrigger?.then((_) => aborted = true);
    }
    return inner.send(request);
  }

  @override
  void close() => inner.close();
}

/// Deliberately ignores cancellation, to exercise the independent timeout race.
class LateClient extends http.BaseClient {
  final response = Completer<http.StreamedResponse>();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      response.future;
}

void main() {
  late HttpServer server;
  late JsonHttpClient client;
  late RecordingClient transport;
  late List<Future<void>> handlers;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    handlers = [];
    server.listen((request) {
      handlers.add(() async {
        try {
          if (request.uri.path == '/api/slow') {
            await Future<void>.delayed(const Duration(milliseconds: 120));
          }
          if (request.uri.path == '/api/failure') {
            request.response.statusCode = 503;
          } else if (request.uri.path == '/api/redirect') {
            request.response.statusCode = 302;
            request.response.headers.set('location', '/api/probe');
          } else if (request.uri.path == '/api/bad') {
            request.response.write('{invalid');
          } else if (request.uri.path == '/api/empty') {
            request.response.statusCode = 204;
          } else {
            final content = await utf8.decoder.bind(request).join();
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'method': request.method,
                'path': request.uri.path,
                'query': request.uri.queryParameters,
                'body': content.isEmpty ? null : jsonDecode(content),
              }),
            );
          }
          await request.response.close();
        } catch (_) {
          /* Requests cancelled by the client may close the socket. */
        }
      }());
    });
    transport = RecordingClient();
    client = JsonHttpClient(
      configuration: HttpConfiguration(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}/api/'),
        probePath: 'probe',
        localDevelopment: true,
      ),
      client: transport,
    );
  });

  tearDown(() async {
    client.close();
    await server.close(force: true);
    await Future.wait(handlers);
  });

  test(
    'real HTTP client sends JSON and configurable URLs and probes reachability',
    () async {
      final response = await client.request(
        'POST',
        'echo',
        body: {'title': 'Test song'},
        query: {'filter': 'local files'},
      ) as Map;
      expect(response['method'], 'POST');
      expect(response['path'], '/api/echo');
      expect(response['query'], {'filter': 'local files'});
      expect(response['body'], {'title': 'Test song'});
      await client.probe();
      expect(await client.request('GET', 'empty'), isNull);
    },
  );

  test(
    'HTTP status errors, redirects and invalid JSON are distinct failures',
    () async {
      await expectLater(
        client.request('GET', 'failure'),
        throwsA(
          failure(NetworkFailureKind.response)
              .having((e) => e.statusCode, 'status', 503),
        ),
      );
      await expectLater(
        client.request('GET', 'redirect'),
        throwsA(failure(NetworkFailureKind.response)),
      );
      await expectLater(
        client.request('GET', 'bad'),
        throwsA(failure(NetworkFailureKind.invalidJson)),
      );
    },
  );

  test('timeout aborts the actual HTTP request', () async {
    await expectLater(
      client.request('GET', 'slow', timeout: const Duration(milliseconds: 15)),
      throwsA(failure(NetworkFailureKind.timeout)),
    );
    await Future<void>.delayed(Duration.zero);
    expect(transport.aborted, isTrue);
  });

  test('caller cancellation and close abort in-flight requests', () async {
    final cancellation = RequestCancellation();
    final request = client.request('GET', 'slow', cancellation: cancellation);
    final assertion = expectLater(
      request,
      throwsA(failure(NetworkFailureKind.cancelled)),
    );
    cancellation.cancel();
    await assertion;
    expect(transport.aborted, isTrue);
    final second = expectLater(
      client.request('GET', 'slow'),
      throwsA(failure(NetworkFailureKind.cancelled)),
    );
    client.close();
    await second;
    await expectLater(
      client.request('GET', 'probe'),
      throwsA(failure(NetworkFailureKind.cancelled)),
    );
  });

  test(
    'clients ignoring abort cannot return a successful late response',
    () async {
      final late = LateClient();
      final isolated = JsonHttpClient(
        configuration: client.configuration,
        client: late,
      );
      await expectLater(
        isolated.request(
          'GET',
          'slow',
          timeout: const Duration(milliseconds: 5),
        ),
        throwsA(failure(NetworkFailureKind.timeout)),
      );
      late.response.complete(
        http.StreamedResponse(Stream.value(utf8.encode('{"late":true}')), 200),
      );
      await Future<void>.delayed(Duration.zero);
      isolated.close();
    },
  );

  test('connection refusal is a transport error', () async {
    final unavailable = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = unavailable.port;
    await unavailable.close(force: true);
    final failed = JsonHttpClient(
      configuration: HttpConfiguration(
        baseUri: Uri.parse('http://127.0.0.1:$port'),
        localDevelopment: true,
      ),
    );
    try {
      await expectLater(
        failed.request('GET', 'probe'),
        throwsA(failure(NetworkFailureKind.transport)),
      );
    } finally {
      failed.close();
    }
  });

  test('configuration rejects insecure targets, escaping endpoints and dev credentials', () async {
    for (final url in [
      'http://192.168.1.2:8000',
      'ftp://localhost',
      'https://user:pass@device.test',
      'https://device.test/?x=1',
    ]) {
      expect(
        () =>
            HttpConfiguration(baseUri: Uri.parse(url), localDevelopment: true),
        throwsA(failure(NetworkFailureKind.configuration)),
      );
    }
    for (final endpoint in [
      'https://elsewhere.test',
      '//elsewhere.test',
      '../secret',
      '%2e%2e/secret',
    ]) {
      await expectLater(
        client.request('GET', endpoint),
        throwsA(failure(NetworkFailureKind.configuration)),
      );
    }
    await expectLater(
      client.request('GET', 'probe', headers: {'Authorization': 'secret'}),
      throwsA(failure(NetworkFailureKind.configuration)),
    );
    await expectLater(
      client.request('POST', 'probe', body: Object()),
      throwsA(failure(NetworkFailureKind.configuration)),
    );
  });
}
