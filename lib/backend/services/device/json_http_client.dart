import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

enum NetworkFailureKind {
  configuration,
  timeout,
  cancelled,
  transport,
  response,
  invalidJson,
}

class NetworkFailure implements Exception {
  const NetworkFailure(this.kind, {this.statusCode});
  final NetworkFailureKind kind;
  final int? statusCode;

  @override
  String toString() =>
      'NetworkFailure(${kind.name}${statusCode == null ? '' : ', $statusCode'})';
}

class RequestCancellation {
  final _completion = Completer<void>();
  Future<void> get cancelled => _completion.future;
  bool get isCancelled => _completion.isCompleted;
  void cancel() {
    if (!isCancelled) _completion.complete();
  }
}

class HttpConfiguration {
  HttpConfiguration({
    required this.baseUri,
    this.probePath,
    this.timeout = const Duration(seconds: 10),
    this.localDevelopment = false,
  }) {
    final loopback = {
      'localhost',
      '127.0.0.1',
      '[::1]',
      '::1',
    }.contains(baseUri.host);
    if (baseUri.host.isEmpty ||
        baseUri.userInfo.isNotEmpty ||
        baseUri.hasQuery ||
        baseUri.hasFragment ||
        timeout <= Duration.zero ||
        (baseUri.scheme != 'https' &&
            !(baseUri.scheme == 'http' && localDevelopment && loopback))) {
      throw const NetworkFailure(NetworkFailureKind.configuration);
    }
  }

  final Uri baseUri;
  final String? probePath;
  final Duration timeout;
  final bool localDevelopment;

  Uri endpoint(String path, Map<String, String>? query) {
    final relative = Uri.tryParse(path);
    if (relative == null ||
        relative.hasScheme ||
        relative.hasAuthority ||
        relative.hasQuery ||
        relative.hasFragment ||
        relative.pathSegments.any((s) => s == '..' || s == '.')) {
      throw const NetworkFailure(NetworkFailureKind.configuration);
    }
    final prefix = baseUri.path.replaceAll(RegExp(r'/+$'), '');
    final suffix = relative.path.replaceAll(RegExp(r'^/+'), '');
    return baseUri.replace(path: '$prefix/$suffix', queryParameters: query);
  }
}

/// Performs real HTTP. Successful responses never imply device authentication.
class JsonHttpClient {
  JsonHttpClient({required this.configuration, http.Client? client})
    : _client = client ?? http.Client();

  final HttpConfiguration configuration;
  final http.Client _client;
  final _pending = <RequestCancellation>{};
  bool _closed = false;

  Future<Object?> request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    Map<String, String> headers = const {},
    Duration? timeout,
    RequestCancellation? cancellation,
  }) async {
    if (_closed) throw const NetworkFailure(NetworkFailureKind.cancelled);
    final limit = timeout ?? configuration.timeout;
    if (limit <= Duration.zero ||
        !{'GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD'}.contains(method)) {
      throw const NetworkFailure(NetworkFailureKind.configuration);
    }
    if (configuration.localDevelopment &&
        headers.keys.any(
          (key) => {
            'authorization',
            'cookie',
            'proxy-authorization',
          }.contains(key.toLowerCase()),
        )) {
      throw const NetworkFailure(NetworkFailureKind.configuration);
    }
    final uri = configuration.endpoint(path, query);
    final local = RequestCancellation();
    _pending.add(local);
    final abort = Future.any<void>([
      local.cancelled,
      if (cancellation != null) cancellation.cancelled,
    ]);
    try {
      if (cancellation?.isCancelled ?? false) {
        throw const NetworkFailure(NetworkFailureKind.cancelled);
      }
      final request = http.AbortableRequest(method, uri, abortTrigger: abort)
        ..followRedirects = false
        ..headers.addAll({'Accept': 'application/json', ...headers});
      if (body != null) {
        try {
          request.body = jsonEncode(body);
        } on JsonUnsupportedObjectError {
          throw const NetworkFailure(NetworkFailureKind.configuration);
        }
        request.headers['Content-Type'] = 'application/json; charset=utf-8';
      }
      // The race also handles injected clients that ignore abortTrigger.
      return await Future.any<Object?>([
        _exchange(request),
        abort.then<Object?>(
          (_) => throw const NetworkFailure(NetworkFailureKind.cancelled),
        ),
      ]).timeout(
        limit,
        onTimeout: () {
          local.cancel();
          throw const NetworkFailure(NetworkFailureKind.timeout);
        },
      );
    } on NetworkFailure {
      rethrow;
    } on http.RequestAbortedException {
      throw const NetworkFailure(NetworkFailureKind.cancelled);
    } catch (_) {
      throw const NetworkFailure(NetworkFailureKind.transport);
    } finally {
      _pending.remove(local);
    }
  }

  Future<Object?> _exchange(http.BaseRequest request) async {
    final response = await _client.send(request);
    final bytes = await response.stream.toBytes();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NetworkFailure(
        NetworkFailureKind.response,
        statusCode: response.statusCode,
      );
    }
    if (bytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const NetworkFailure(NetworkFailureKind.invalidJson);
    }
  }

  Future<void> probe({RequestCancellation? cancellation}) async {
    final path = configuration.probePath;
    if (path == null) {
      throw const NetworkFailure(NetworkFailureKind.configuration);
    }
    await request('GET', path, cancellation: cancellation);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    for (final request in _pending.toList()) {
      request.cancel();
    }
    _client.close();
  }
}
