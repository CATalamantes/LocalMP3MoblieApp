import 'dart:math';

import '../../models/device_models.dart';
import 'connection_manager.dart';
import 'device_contracts.dart';
import 'device_protocol.dart';
import 'json_http_client.dart';

String _requestId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Typed remote-device facade. Never controls the local phone audio engine.
class RadxaClient {
  RadxaClient.production(this.connections)
    : testOnly = false,
      _id = _requestId {
    connections.addListener(_connectionChanged);
  }
  RadxaClient.forTesting(this.connections, {String Function()? requestId})
    : testOnly = true,
      _id = requestId ?? _requestId {
    connections.addListener(_connectionChanged);
  }
  final ConnectionManager connections;
  final bool testOnly;
  final String Function() _id;
  DeviceCapabilities? _capabilities;
  int? _capabilitySession;
  int _capabilityRequest = 0;
  bool _disposed = false;
  final _pending = <RequestCancellation>{};
  DeviceCapabilities? get capabilities =>
      _capabilitySession == connections.sessionGeneration
      ? _capabilities
      : null;

  void _connectionChanged() {
    if (connections.snapshot.phase != ConnectionPhase.authenticated ||
        _capabilitySession != connections.sessionGeneration) {
      _capabilities = null;
      _capabilitySession = null;
      ++_capabilityRequest;
    }
  }

  void _authorized() {
    if (_disposed) throw const DeviceFailure(DeviceFailureKind.cancelled);
    // No capability switch promotes test connections into production trust.
    if (!testOnly ||
        !connections.testOnly ||
        !connections.snapshot.testOnly ||
        connections.snapshot.phase != ConnectionPhase.authenticated) {
      throw const DeviceFailure(DeviceFailureKind.unavailable);
    }
  }

  void _identifier(String id) {
    if (id.trim().isEmpty) {
      throw const DeviceFailure(DeviceFailureKind.invalidInput);
    }
  }

  Future<Object?> _send(
    DeviceOperation operation,
    Map<String, Object?> payload,
  ) async {
    _authorized();
    if (!{
          DeviceOperation.status,
          DeviceOperation.capabilities,
        }.contains(operation) &&
        !(capabilities?.supports(operation) ?? false)) {
      throw const DeviceFailure(DeviceFailureKind.unsupported);
    }
    final generation = connections.sessionGeneration;
    final id = _id();
    final request = DeviceProtocol.request(id, operation, payload);
    final cancellation = RequestCancellation();
    _pending.add(cancellation);
    try {
      final raw = await connections.send(
        operation.name,
        payload: request,
        cancellation: cancellation,
      );
      if (_disposed || generation != connections.sessionGeneration) {
        throw const DeviceFailure(DeviceFailureKind.cancelled);
      }
      return DeviceProtocol.response(raw, id);
    } on NetworkFailure catch (failure) {
      final mapped = DeviceProtocol.fromNetwork(failure);
      if (!_disposed && generation == connections.sessionGeneration) {
        await _terminal(mapped);
      }
      throw DeviceCommandFailure(
        mapped.kind,
        outcomeUnknown:
            operation.changesState &&
            {
              NetworkFailureKind.timeout,
              NetworkFailureKind.transport,
              NetworkFailureKind.cancelled,
              NetworkFailureKind.invalidJson,
            }.contains(failure.kind),
      );
    } on DeviceFailure catch (failure) {
      if (generation == connections.sessionGeneration) await _terminal(failure);
      throw DeviceCommandFailure(
        failure.kind,
        outcomeUnknown:
            operation.changesState &&
            {
              DeviceFailureKind.transient,
              DeviceFailureKind.cancelled,
              DeviceFailureKind.protocol,
            }.contains(failure.kind),
      );
    } finally {
      _pending.remove(cancellation);
    }
  }

  Future<void> _terminal(DeviceFailure failure) async {
    if ({
      DeviceFailureKind.identity,
      DeviceFailureKind.authentication,
      DeviceFailureKind.authorization,
    }.contains(failure.kind)) {
      _capabilities = null;
      try {
        await connections.rejectSession(failure.kind);
      } catch (_) {
        /* Retain the security error after invalidation. */
      }
    }
  }

  Future<DeviceStatus> requestStatus() async {
    final request = ++_capabilityRequest;
    final generation = connections.sessionGeneration;
    final id = connections.connectedDeviceId;
    final raw = await _send(DeviceOperation.status, {});
    try {
      if (id == null ||
          generation != connections.sessionGeneration ||
          request != _capabilityRequest ||
          _disposed) {
        throw const DeviceFailure(DeviceFailureKind.cancelled);
      }
      final status = DeviceProtocol.status(
        raw,
        expectedDeviceId: id,
        testOnly: testOnly,
      );
      _capabilities = status.capabilities;
      _capabilitySession = generation;
      return status;
    } on DeviceFailure catch (failure) {
      await _terminal(failure);
      rethrow;
    }
  }

  Future<DeviceCapabilities> readCapabilities() async {
    final request = ++_capabilityRequest;
    final generation = connections.sessionGeneration;
    final value = DeviceProtocol.capabilities(
      await _send(DeviceOperation.capabilities, {}),
    );
    if (generation != connections.sessionGeneration ||
        _disposed ||
        request != _capabilityRequest) {
      throw const DeviceFailure(DeviceFailureKind.cancelled);
    }
    _capabilities = value;
    _capabilitySession = generation;
    return value;
  }

  Future<void> _action(
    DeviceOperation operation, [
    Map<String, Object?> payload = const {},
  ]) async {
    final result = await _send(operation, payload);
    try {
      DeviceProtocol.acknowledgement(result);
    } on DeviceFailure catch (failure) {
      throw DeviceCommandFailure(failure.kind, outcomeUnknown: true);
    }
  }

  Future<void> play({String? songId}) {
    if (songId != null) _identifier(songId);
    return _action(DeviceOperation.play, {'song_id': ?songId});
  }

  Future<void> pause() => _action(DeviceOperation.pause);
  Future<void> resume() => _action(DeviceOperation.resume);
  Future<void> stop() => _action(DeviceOperation.stop);
  Future<void> next() => _action(DeviceOperation.next);
  Future<void> previous() => _action(DeviceOperation.previous);
  Future<void> seek(Duration position) {
    if (position < Duration.zero) {
      throw const DeviceFailure(DeviceFailureKind.invalidInput);
    }
    return _action(DeviceOperation.seek, {
      'position_ms': position.inMilliseconds,
    });
  }

  Future<RemotePlaybackState> readPlaybackState() async =>
      DeviceProtocol.playback(
        await _send(DeviceOperation.playbackState, {}),
        testOnly: testOnly,
      );
  Future<void> startRecording() => _action(DeviceOperation.startRecording);
  Future<void> stopRecording() => _action(DeviceOperation.stopRecording);
  Future<RemoteRecordingState> readRecordingState() async =>
      DeviceProtocol.recording(
        await _send(DeviceOperation.recordingState, {}),
        testOnly: testOnly,
      );
  Future<RecordingMetadata> readRecordingMetadata(String id) async {
    _identifier(id);
    final result = DeviceProtocol.recordingMetadata(
      await _send(DeviceOperation.recordingMetadata, {'recording_id': id}),
      testOnly: testOnly,
    );
    if (result.recordingId != id) DeviceProtocol.fail();
    return result;
  }

  Future<List<RemoteFile>> listFiles() async => DeviceProtocol.files(
    await _send(DeviceOperation.listFiles, {}),
    testOnly: testOnly,
  );
  Future<void> removeFile(String fileId) {
    _identifier(fileId);
    return _action(DeviceOperation.removeFile, {'file_id': fileId});
  }

  Future<DownloadJob> requestDownload(Uri url) async {
    if (!{'http', 'https'}.contains(url.scheme) ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty) {
      throw const DeviceFailure(DeviceFailureKind.invalidInput);
    }
    return DeviceProtocol.download(
      await _send(DeviceOperation.submitDownload, {'url': url.toString()}),
      testOnly: testOnly,
    );
  }

  Future<DownloadJob> readDownloadStatus(String id) async {
    _identifier(id);
    final result = DeviceProtocol.download(
      await _send(DeviceOperation.downloadStatus, {'job_id': id}),
      testOnly: testOnly,
    );
    if (result.jobId != id) DeviceProtocol.fail();
    return result;
  }

  Future<DeviceTransferHandle> uploadAudio(
    Uri localFile, {
    required String remoteName,
  }) async {
    _authorized();
    _identifier(remoteName);
    if (localFile.scheme != 'file') {
      throw const DeviceFailure(DeviceFailureKind.invalidInput);
    }
    return _unavailableTransfer();
  }

  Future<DeviceTransferHandle> downloadRecording(
    String fileId, {
    required Uri destination,
  }) async {
    _authorized();
    _identifier(fileId);
    if (destination.scheme != 'file') {
      throw const DeviceFailure(DeviceFailureKind.invalidInput);
    }
    return _unavailableTransfer();
  }

  Never _unavailableTransfer() {
    if (connections.snapshot.transport != TransportKind.wifi) {
      throw const DeviceFailure(DeviceFailureKind.unsupported);
    }
    throw const DeviceFailure(DeviceFailureKind.unavailable);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_capabilityRequest;
    connections.removeListener(_connectionChanged);
    for (final request in _pending) {
      request.cancel();
    }
    _pending.clear();
    _capabilities = null;
  }
}
