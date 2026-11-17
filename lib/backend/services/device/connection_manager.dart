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
  DeviceSettings? _savedSession;
  DeviceCredentials? _secretSession;
  String? get connectedDeviceId =>
      _active == null ? null : _savedSession?.deviceId;
  int get sessionGeneration => _generation;
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
    _savedSession = null;
    _secretSession = null;
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
        ConnectionSnapshot(
          automatic ? ConnectionPhase.reconnecting : ConnectionPhase.connecting,
          testOnly: testOnly,
        ),
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
        if (!await _trustMatches(saved, secret)) {
          if (_current(generation)) await disconnect();
          return;
        }
        if (!_current(generation)) return;
        try {
          await _authenticate(_wifi, saved, secret, cancellation);
          if (!_current(generation)) return;
          if (!await _trustMatches(saved, secret)) {
            await _wifi.disconnect();
            if (_current(generation)) await disconnect();
            return;
          }
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
              if (!await _trustMatches(saved, secret)) {
                await ble.disconnect();
                if (_current(generation)) await disconnect();
                return;
              }
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
        _savedSession = saved;
        _secretSession = secret;
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

  Future<bool> _trustMatches(
    DeviceSettings saved,
    DeviceCredentials secret,
  ) async {
    try {
      final current = await settings.read();
      final credential = await credentials.read();
      return current != null &&
          credential != null &&
          current.deviceId == saved.deviceId &&
          current.baseUri == saved.baseUri &&
          current.autoReconnect == saved.autoReconnect &&
          credential.deviceId == secret.deviceId &&
          credential.credential == secret.credential &&
          credential.pinnedIdentity == secret.pinnedIdentity;
    } on DeviceFailure {
      rethrow;
    } catch (_) {
      throw const DeviceFailure(DeviceFailureKind.storage);
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
    Duration timeout = const Duration(seconds: 10),
    RequestCancellation? cancellation,
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
    if (timeout <= Duration.zero) {
      throw const DeviceFailure(DeviceFailureKind.invalidInput);
    }
    if (!await _trustMatches(_savedSession!, _secretSession!)) {
      if (_current(generation)) await disconnect();
      throw const DeviceFailure(DeviceFailureKind.untrusted);
    }
    if (!_current(generation) || (cancellation?.isCancelled ?? false)) {
      throw const DeviceFailure(DeviceFailureKind.cancelled);
    }
    final request = RequestCancellation();
    // A request timeout cancels this command, not an unrelated command/session.
    final ended = RequestCancellation();
    unawaited(
      Future.any([
        _operation!.cancelled,
        if (cancellation != null) cancellation.cancelled,
        ended.cancelled,
      ]).then((_) {
        if (!ended.isCancelled) request.cancel();
      }),
    );
    try {
      final result =
          await Future.any([
            transport.send(operation, payload, request),
            request.cancelled.then<Object?>(
              (_) => throw const DeviceFailure(DeviceFailureKind.cancelled),
            ),
          ]).timeout(
            timeout,
            onTimeout: () {
              request.cancel();
              throw const DeviceFailure(DeviceFailureKind.transient);
            },
          );
      if (!_current(generation)) {
        throw const DeviceFailure(DeviceFailureKind.cancelled);
      }
      return result;
    } on DeviceFailure catch (failure) {
      if ({
            DeviceFailureKind.identity,
            DeviceFailureKind.authentication,
            DeviceFailureKind.authorization,
          }.contains(failure.kind) &&
          _current(generation)) {
        try {
          await rejectSession(failure.kind);
        } catch (_) {
          /* Preserve the security failure after invalidation. */
        }
      }
      rethrow;
    } finally {
      ended.cancel();
    }
  }

  Future<void> disconnect() async {
    _operation?.cancel();
    final generation = ++_generation;
    final active = _active;
    _active = null;
    _savedSession = null;
    _secretSession = null;
    _publish(
      ConnectionSnapshot(ConnectionPhase.disconnected, testOnly: testOnly),
      generation,
    );
    await active?.disconnect();
  }

  /// A security failure invalidates the session; reachability cannot repair it.
  Future<void> rejectSession(DeviceFailureKind failure) async {
    if (_disposed) return;
    if (!{
      DeviceFailureKind.authentication,
      DeviceFailureKind.authorization,
      DeviceFailureKind.identity,
    }.contains(failure)) {
      throw const DeviceFailure(DeviceFailureKind.invalidInput);
    }
    _operation?.cancel();
    final generation = ++_generation;
    final active = _active;
    _active = null;
    _savedSession = null;
    _secretSession = null;
    _publish(
      ConnectionSnapshot(
        ConnectionPhase.failed,
        failure: failure,
        testOnly: testOnly,
      ),
      generation,
    );
    await active?.disconnect();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    _operation?.cancel();
    final active = _active;
    _active = null;
    _savedSession = null;
    _secretSession = null;
    if (active != null) {
      unawaited(active.disconnect().catchError((Object _) {}));
    }
    super.dispose();
  }
}
