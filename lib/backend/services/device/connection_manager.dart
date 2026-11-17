import 'dart:async';

import 'package:flutter/foundation.dart';

import 'device_contracts.dart';
import 'json_http_client.dart';

typedef ReconnectWait = Future<void> Function(
  Duration delay,
  RequestCancellation cancellation,
);

Future<void> _wait(Duration delay, RequestCancellation cancellation) =>
    Future.any([Future<void>.delayed(delay), cancellation.cancelled]);

class ConnectionManager extends ChangeNotifier {
  ConnectionManager.production({
    required this.settings,
    required this.credentials,
  }) : _wifi = null,
       _ble = null,
       _waitForRetry = _wait,
       testOnly = false;

  ConnectionManager.forTesting({
    required this.settings,
    required this.credentials,
    required DeviceTransport wifiTransport,
    DeviceTransport? bleTransport,
    ReconnectWait? waitForRetry,
  }) : _wifi = wifiTransport,
       _ble = bleTransport,
       _waitForRetry = waitForRetry ?? _wait,
       testOnly = true;

  final DeviceSettingsStore settings;
  final CredentialStore credentials;
  final DeviceTransport? _wifi, _ble;
  final ReconnectWait _waitForRetry;
  final bool testOnly;
  ConnectionSnapshot _snapshot = const ConnectionSnapshot(
    ConnectionPhase.disconnected,
  );
  ConnectionSnapshot get snapshot => _snapshot;
  DeviceTransport? _active;
  RequestCancellation? _operation;
  int _generation = 0;
  bool _disposed = false;

  bool _current(int generation) => !_disposed && generation == _generation;
  void _publish(ConnectionSnapshot snapshot, int generation) {
    if (!_current(generation)) return;
    _snapshot = snapshot;
    notifyListeners();
  }

  Future<void> reconnect({
    String? operation,
    bool largeTransfer = false,
    bool automatic = true,
  }) async {
    if (_disposed) throw const DeviceFailure(DeviceFailureKind.cancelled);
    _operation?.cancel();
    final generation = ++_generation;
    final cancellation = _operation = RequestCancellation();
    final previous = _active;
    _active = null;
    // No future or injected test outcome can enable a production connection.
    if (!testOnly || _wifi == null) {
      _publish(
        const ConnectionSnapshot(
          ConnectionPhase.unavailable,
          failure: DeviceFailureKind.unavailable,
        ),
        generation,
      );
      return;
    }
    try {
      await previous?.disconnect();
      if (!_current(generation)) return;
      final saved = await settings.read();
      final secret = await credentials.read();
      if (!_current(generation)) return;
      if (saved == null && secret == null) {
        _publish(
          ConnectionSnapshot(ConnectionPhase.disconnected, testOnly: testOnly),
          generation,
        );
        return;
      }
      if (saved == null ||
          secret == null ||
          saved.deviceId != secret.deviceId ||
          secret.credential.isEmpty ||
          secret.pinnedIdentity.isEmpty ||
          saved.baseUri.scheme != 'https') {
        throw const DeviceFailure(DeviceFailureKind.untrusted);
      }
      HttpConfiguration(baseUri: saved.baseUri);
      if (automatic && !saved.autoReconnect) {
        _publish(
          ConnectionSnapshot(ConnectionPhase.disconnected, testOnly: testOnly),
          generation,
        );
        return;
      }
      _publish(
        ConnectionSnapshot(ConnectionPhase.reconnecting, testOnly: testOnly),
        generation,
      );
      for (var attempt = 0; attempt < 4; attempt++) {
        if (!_current(generation)) return;
        if (attempt > 0) {
          await _waitForRetry(
            Duration(seconds: 1 << (attempt - 1)),
            cancellation,
          );
          if (!_current(generation)) return;
        }
        try {
          await _authenticate(_wifi, saved, secret, cancellation);
          if (!_current(generation)) return;
          _active = _wifi;
        } on DeviceFailure catch (error) {
          if (!_current(generation)) return;
          // Auth/identity errors are terminal: never downgrade security.
          if (error.kind != DeviceFailureKind.transient) rethrow;
          final ble = _ble;
          if (!largeTransfer &&
              operation != null &&
              ble != null &&
              ble.supports(operation)) {
            try {
              await _authenticate(ble, saved, secret, cancellation);
              if (!_current(generation)) return;
              _active = ble;
            } on DeviceFailure catch (bleError) {
              if (bleError.kind != DeviceFailureKind.transient) rethrow;
            }
          }
          if (_active == null) {
            if (attempt == 3) rethrow;
            continue;
          }
        }
        _publish(
          ConnectionSnapshot(
            ConnectionPhase.authenticated,
            transport: _active!.kind,
            testOnly: true,
          ),
          generation,
        );
        return;
      }
    } on DeviceFailure catch (error) {
      _publish(
        ConnectionSnapshot(
          ConnectionPhase.failed,
          failure: error.kind,
          testOnly: testOnly,
        ),
        generation,
      );
    } catch (_) {
      _publish(
        ConnectionSnapshot(
          ConnectionPhase.failed,
          failure: DeviceFailureKind.storage,
          testOnly: testOnly,
        ),
        generation,
      );
    }
  }

  Future<void> _authenticate(
    DeviceTransport transport,
    DeviceSettings settings,
    DeviceCredentials credentials,
    RequestCancellation cancellation,
  ) async {
    final attempt = RequestCancellation();
    try {
      await Future.any([
        transport.authenticate(settings, credentials, attempt),
        cancellation.cancelled.then<void>((_) {
          attempt.cancel();
          throw const DeviceFailure(DeviceFailureKind.cancelled);
        }),
      ]).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          attempt.cancel();
          throw TimeoutException('Authentication timed out');
        },
      );
    } on TimeoutException {
      throw const DeviceFailure(DeviceFailureKind.transient);
    }
  }

  Future<Object?> send(
    String operation, {
    Object? payload,
    bool largeTransfer = false,
  }) async {
    final transport = _active;
    if (!testOnly || transport == null) {
      throw const DeviceFailure(DeviceFailureKind.unavailable);
    }
    if (!transport.supports(operation) ||
        (largeTransfer && transport.kind != TransportKind.wifi)) {
      throw const DeviceFailure(DeviceFailureKind.unsupported);
    }
    final generation = _generation;
    final cancellation = _operation!;
    final result = await Future.any([
      transport.send(operation, payload, cancellation),
      cancellation.cancelled.then<Object?>(
        (_) => throw const DeviceFailure(DeviceFailureKind.cancelled),
      ),
    ]);
    if (!_current(generation)) {
      throw const DeviceFailure(DeviceFailureKind.cancelled);
    }
    return result;
  }

  Future<void> disconnect() async {
    _operation?.cancel();
    final generation = ++_generation;
    final active = _active;
    _active = null;
    _publish(
      ConnectionSnapshot(ConnectionPhase.disconnected, testOnly: testOnly),
      generation,
    );
    await active?.disconnect();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _operation?.cancel();
    final active = _active;
    _active = null;
    if (active != null) {
      unawaited(active.disconnect().catchError((Object _) {}));
    }
    super.dispose();
  }
}
