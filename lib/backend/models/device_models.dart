// Service data only. These types do not add SQLite tables or device trust.
enum DeviceOperation {
  status,
  capabilities,
  playbackState,
  play,
  pause,
  resume,
  stop,
  next,
  previous,
  seek,
  startRecording,
  stopRecording,
  recordingState,
  recordingMetadata,
  listFiles,
  removeFile,
  submitDownload,
  downloadStatus,
}

extension DeviceOperationPolicy on DeviceOperation {
  bool get changesState => !{
    DeviceOperation.status,
    DeviceOperation.capabilities,
    DeviceOperation.playbackState,
    DeviceOperation.recordingState,
    DeviceOperation.recordingMetadata,
    DeviceOperation.listFiles,
    DeviceOperation.downloadStatus,
  }.contains(this);
}

class NearbyDevice {
  const NearbyDevice({required this.discoveryId, this.displayName});
  // An opaque discovery handle, never authenticated identity.
  final String discoveryId;
  final String? displayName;
}

class PairingWindow {
  const PairingWindow({required this.open, required this.expiresAt});
  final bool open;
  final DateTime expiresAt;
  bool isOpenAt(DateTime now) => open && now.isBefore(expiresAt);
}

class TrustedDeviceSummary {
  const TrustedDeviceSummary({
    required this.deviceId,
    required this.baseUri,
    required this.autoReconnect,
    required this.testOnly,
  });
  final String deviceId;
  final Uri baseUri;
  final bool autoReconnect, testOnly;
}

class DeviceCapabilities {
  DeviceCapabilities(Iterable<String> operations)
    : operations = Set.unmodifiable(operations);
  final Set<String> operations;
  bool supports(DeviceOperation operation) =>
      operations.contains(operation.name);
}

class DeviceStatus {
  const DeviceStatus({
    required this.deviceId,
    required this.capabilities,
    required this.testOnly,
    this.firmwareVersion,
    this.batteryPercent,
    this.charging,
    this.storageBytes,
    this.freeBytes,
  });
  final String deviceId;
  final DeviceCapabilities capabilities;
  final bool testOnly;
  final String? firmwareVersion;
  final int? batteryPercent, storageBytes, freeBytes;
  final bool? charging;
}

enum RemotePlaybackPhase {
  idle,
  loading,
  ready,
  playing,
  paused,
  buffering,
  completed,
  error,
}

class RemotePlaybackState {
  const RemotePlaybackState({
    required this.phase,
    required this.testOnly,
    this.songId,
    this.position,
    this.duration,
  });
  final RemotePlaybackPhase phase;
  final bool testOnly;
  final String? songId;
  final Duration? position, duration;
}

enum RemoteRecordingPhase { idle, recording, stopped, failed }

class RemoteRecordingState {
  const RemoteRecordingState({
    required this.phase,
    required this.testOnly,
    this.recordingId,
  });
  final RemoteRecordingPhase phase;
  final bool testOnly;
  final String? recordingId;
}

class RemoteFile {
  const RemoteFile({
    required this.fileId,
    required this.name,
    required this.testOnly,
    this.sizeBytes,
  });
  final String fileId, name;
  final bool testOnly;
  final int? sizeBytes;
}

class RecordingMetadata {
  const RecordingMetadata({
    required this.recordingId,
    required this.testOnly,
    this.fileId,
    this.duration,
  });
  final String recordingId;
  final bool testOnly;
  final String? fileId;
  final Duration? duration;
}

enum DownloadPhase { queued, running, completed, failed, cancelled }

class DownloadJob {
  const DownloadJob({
    required this.jobId,
    required this.phase,
    required this.testOnly,
  });
  final String jobId;
  final DownloadPhase phase;
  final bool testOnly;
}

enum DeviceTransferPhase { pending, running, completed, cancelled, failed }

class DeviceTransferSnapshot {
  const DeviceTransferSnapshot({
    required this.phase,
    required this.transferredBytes,
    required this.testOnly,
    this.totalBytes,
  });
  final DeviceTransferPhase phase;
  final int transferredBytes;
  final int? totalBytes;
  final bool testOnly;
}
