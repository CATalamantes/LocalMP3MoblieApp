import 'dart:async';

import '../models/device_models.dart';
import '../services/device/connection_manager.dart';
import '../services/device/device_contracts.dart';
import '../services/device/pairing_service.dart';
import '../services/device/radxa_client.dart';
import 'controller_state.dart';

enum DevicePhase {
  noTrustedDevice,
  discoveredUntrusted,
  pairing,
  trustedDeviceSaved,
  connecting,
  authenticated,
  testConnected,
  disconnected,
  reconnecting,
  forgetting,
  error,
  unavailable,
}

class DeviceControllerFailure extends ControllerFailure {
  const DeviceControllerFailure(this.deviceFailure)
    : super(
        deviceFailure == DeviceFailureKind.storage
            ? ControllerFailureKind.storage
            : deviceFailure == DeviceFailureKind.invalidInput
            ? ControllerFailureKind.invalidInput
            : ControllerFailureKind.unavailable,
        'Device operation failed',
      );
  final DeviceFailureKind deviceFailure;
  @override
  String toString() => 'DeviceControllerFailure(${deviceFailure.name})';
}

class DeviceData {
  DeviceData({
    this.phase = DevicePhase.noTrustedDevice,
    this.trustedDevice,
    Iterable<NearbyDevice> nearby = const [],
    this.status,
    this.capabilities,
    this.failure,
    this.testOnly = false,
  }) : nearby = List.unmodifiable(nearby);
  final DevicePhase phase;
  final TrustedDeviceSummary? trustedDevice;
  final List<NearbyDevice> nearby;
  final DeviceStatus? status;
  final DeviceCapabilities? capabilities;
  final DeviceFailureKind? failure;
  final bool testOnly;
  bool get hardwareAuthenticated =>
      phase == DevicePhase.authenticated && !testOnly;
}

class DeviceController extends MusicController<DeviceData> {
  DeviceController({
    required this.connections,
    required this.pairing,
    required this.client,
  }) : super(DeviceData(testOnly: client.testOnly)) {
    connections.addListener(_connectionChanged);
  }
  final ConnectionManager connections;
  final PairingService pairing;
  final RadxaClient client;
  bool _closed = false;
  int _request = 0;
  int? _connectingRequest, _pairingRequest;
  DeviceFailureKind? _securityFailure;
  Future<void>? _shutdown;

  @override
  bool isEmpty(DeviceData data) => data.phase == DevicePhase.noTrustedDevice;
  @override
  ControllerFailure mapFailure(Object error) => error is DeviceFailure
      ? DeviceControllerFailure(error.kind)
      : super.mapFailure(error);
  @override
  ControllerFailure? failureForData(DeviceData data) =>
      data.failure == null ? null : DeviceControllerFailure(data.failure!);
  @override
  DeviceData prepareErrorData(DeviceData data, ControllerFailure failure) {
    final kind = failure is DeviceControllerFailure
        ? failure.deviceFailure
        : DeviceFailureKind.storage;
    _rememberSecurity(kind);
    return _data(
      phase:
          kind == DeviceFailureKind.unavailable ||
              kind == DeviceFailureKind.unsupported
          ? DevicePhase.unavailable
          : DevicePhase.error,
      failure: _securityFailure ?? kind,
    );
  }

  DeviceData _data({
    DevicePhase? phase,
    TrustedDeviceSummary? trusted,
    Iterable<NearbyDevice>? nearby,
    DeviceStatus? status,
    DeviceCapabilities? capabilities,
    DeviceFailureKind? failure,
    bool clearDevice = false,
    bool clearTelemetry = false,
  }) {
    final before = state.data;
    return DeviceData(
      phase: phase ?? before.phase,
      trustedDevice: clearDevice ? null : trusted ?? before.trustedDevice,
      nearby: clearDevice ? const [] : nearby ?? before.nearby,
      status: clearDevice || clearTelemetry ? null : status ?? before.status,
      capabilities: clearDevice || clearTelemetry
          ? null
          : capabilities ?? before.capabilities,
      failure: failure ?? _securityFailure,
      testOnly: client.testOnly,
    );
  }

  void _rememberSecurity(DeviceFailureKind? kind) {
    if ({
      DeviceFailureKind.identity,
      DeviceFailureKind.authentication,
      DeviceFailureKind.authorization,
    }.contains(kind)) {
      _securityFailure = kind;
    }
  }

  void _check(int request) {
    ensureActive();
    if (_closed || request != _request) {
      throw const DeviceFailure(DeviceFailureKind.cancelled);
    }
  }

  Future<void> _perform(
    DevicePhase phase,
    Future<DeviceData> Function(int request) work, {
    bool clearDevice = false,
    bool clearTelemetry = false,
    bool connectionAttempt = false,
    bool enrollment = false,
  }) {
    ensureActive();
    final cancellation = _connectingRequest == null
        ? null
        : connections.disconnect();
    if (_pairingRequest != null) pairing.cancel();
    final request = ++_request;
    _connectingRequest = connectionAttempt ? request : null;
    _pairingRequest = enrollment ? request : null;
    changeData(
      _data(
        phase: phase,
        clearDevice: clearDevice,
        clearTelemetry: clearTelemetry,
      ),
    );
    return execute(() async {
      try {
        await cancellation;
        _check(request);
        final result = await work(request);
        _check(request);
        return ControllerResult(result, null);
      } finally {
        if (_connectingRequest == request) _connectingRequest = null;
        if (_pairingRequest == request) _pairingRequest = null;
      }
    });
  }

  DevicePhase _phase(ConnectionSnapshot snapshot) => switch (snapshot.phase) {
    ConnectionPhase.authenticated =>
      snapshot.testOnly
          ? (client.testOnly
                ? DevicePhase.testConnected
                : DevicePhase.unavailable)
          : (snapshot.hardwareAuthenticated && !client.testOnly
                ? DevicePhase.authenticated
                : DevicePhase.unavailable),
    ConnectionPhase.connecting => DevicePhase.connecting,
    ConnectionPhase.reconnecting => DevicePhase.reconnecting,
    ConnectionPhase.disconnected => DevicePhase.disconnected,
    ConnectionPhase.unavailable => DevicePhase.unavailable,
    ConnectionPhase.failed => DevicePhase.error,
  };
  void _connectionChanged() {
    if (_closed) return;
    final snapshot = connections.snapshot;
    _rememberSecurity(snapshot.failure);
    final failure = _securityFailure ?? snapshot.failure;
    final busy = {
      DevicePhase.pairing,
      DevicePhase.forgetting,
    }.contains(state.data.phase);
    publishEventData(
      _data(
        phase: failure != null && _securityFailure != null
            ? DevicePhase.error
            : busy
            ? state.data.phase
            : _phase(snapshot),
        clearTelemetry: snapshot.phase != ConnectionPhase.authenticated,
        failure: failure,
      ),
      failure: failure == null ? null : DeviceControllerFailure(failure),
    );
  }

  Future<void> loadSavedDevice() =>
      _perform(DevicePhase.disconnected, (request) async {
        final saved = await pairing.loadSavedDevice();
        _check(request);
        return saved == null
            ? _data(phase: DevicePhase.noTrustedDevice, clearDevice: true)
            : _data(phase: DevicePhase.trustedDeviceSaved, trusted: saved);
      });
  Future<void> scanForDevices() =>
      _perform(DevicePhase.discoveredUntrusted, (request) async {
        final nearby = await pairing.discover();
        _check(request);
        return _data(
          phase: nearby.isEmpty
              ? (state.data.trustedDevice == null
                    ? DevicePhase.noTrustedDevice
                    : DevicePhase.trustedDeviceSaved)
              : DevicePhase.discoveredUntrusted,
          nearby: nearby,
        );
      });
  Future<void> pairWithCode(String discoveryId, String passkey) {
    pairing.cancel();
    return _perform(
      DevicePhase.pairing,
      (request) async {
        await connections.disconnect();
        _check(request);
        await pairing.pair(discoveryId, passkey);
        _check(request);
        final saved = await pairing.loadSavedDevice();
        _check(request);
        return _data(
          phase: DevicePhase.trustedDeviceSaved,
          trusted: saved,
          nearby: const [],
        );
      },
      clearTelemetry: true,
      enrollment: true,
    );
  }

  Future<void> connect() => _connect(false);
  Future<void> autoReconnect() => _connect(true);
  Future<void> _connect(bool automatic) {
    pairing.cancel();
    return _perform(
      automatic ? DevicePhase.reconnecting : DevicePhase.connecting,
      (request) async {
        final saved = await pairing.loadSavedDevice();
        _check(request);
        await connections.reconnect(automatic: automatic);
        _check(request);
        final snapshot = connections.snapshot;
        _rememberSecurity(snapshot.failure);
        if (snapshot.failure != null) throw DeviceFailure(snapshot.failure!);
        if (snapshot.phase == ConnectionPhase.authenticated &&
            (snapshot.hardwareAuthenticated ||
                (snapshot.testOnly && client.testOnly))) {
          _securityFailure = null;
        }
        return _data(phase: _phase(snapshot), trusted: saved);
      },
      clearTelemetry: true,
      connectionAttempt: true,
    );
  }

  Future<void> disconnect() {
    pairing.cancel();
    final pending = connections.disconnect();
    return _perform(DevicePhase.disconnected, (request) async {
      await pending;
      _check(request);
      return _data(phase: DevicePhase.disconnected, clearTelemetry: true);
    }, clearTelemetry: true);
  }

  Future<void> refreshDeviceInfo() =>
      _perform(state.data.phase, (request) async {
        final status = await client.requestStatus();
        _check(request);
        return _data(status: status, capabilities: status.capabilities);
      });
  Future<void> readCapabilities() =>
      _perform(state.data.phase, (request) async {
        final capabilities = await client.readCapabilities();
        _check(request);
        return _data(capabilities: capabilities);
      });
  Future<void> forgetDevice() {
    pairing.cancel();
    final disconnected = connections.disconnect();
    return _perform(DevicePhase.forgetting, (request) async {
      await disconnected;
      _check(request);
      await pairing.forget();
      _check(request);
      _securityFailure = null;
      return _data(phase: DevicePhase.noTrustedDevice, clearDevice: true);
    }, clearDevice: true);
  }

  Future<void> updateConnectionSettings(DeviceSettings settings) {
    pairing.cancel();
    final disconnected = connections.disconnect();
    return _perform(DevicePhase.disconnected, (request) async {
      await disconnected;
      _check(request);
      await pairing.updateSettings(settings);
      _check(request);
      final saved = await pairing.loadSavedDevice();
      _check(request);
      return _data(phase: DevicePhase.trustedDeviceSaved, trusted: saved);
    }, clearTelemetry: true);
  }

  // Headphones use a separate device-side audio profile, not BLE control pairing.
  Future<void> selectHeadphones(String id) => _perform(
    DevicePhase.unavailable,
    (_) async => throw const DeviceFailure(DeviceFailureKind.unsupported),
  );

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    ++_request;
    connections.removeListener(_connectionChanged);
    client.dispose();
    pairing.dispose();
    connections.dispose();
    _shutdown = pairing.close();
    unawaited(_shutdown!.catchError((Object _) {}));
    super.dispose();
  }

  Future<void> close() async {
    dispose();
    await _shutdown;
  }
}
