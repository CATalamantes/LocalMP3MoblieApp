import '../../models/device_models.dart';
import 'device_contracts.dart';
import 'json_http_client.dart';

/// Proposal v1 codec only. This is not an agreed or authenticated Radxa protocol.
class DeviceProtocol {
  static const version = 1;
  static Map<String, Object?> request(
    String id,
    DeviceOperation operation,
    Map<String, Object?> payload,
  ) {
    if (id.trim().isEmpty) {
      throw const DeviceFailure(DeviceFailureKind.invalidInput);
    }
    return {
      'protocol_version': version,
      'request_id': id,
      'operation': operation.name,
      'payload': payload,
    };
  }

  static Map<String, Object?> validateCandidate(Object? value) {
    final map = object(value);
    if (map['protocol_version'] != version) fail();
    text(map, 'request_id');
    final operation = text(map, 'operation');
    if (!DeviceOperation.values.any((v) => v.name == operation)) fail();
    object(map['payload']);
    return map;
  }

  static Object? response(Object? raw, String id) {
    final map = object(raw);
    if (map['protocol_version'] != version ||
        map['request_id'] != id ||
        map.containsKey('result') == map.containsKey('error')) {
      fail();
    }
    if (map.containsKey('error')) {
      final error = object(map['error']);
      final kind = switch (text(error, 'code')) {
        'unauthenticated' => DeviceFailureKind.authentication,
        'forbidden' => DeviceFailureKind.authorization,
        'identity_mismatch' => DeviceFailureKind.identity,
        'unsupported' => DeviceFailureKind.unsupported,
        'unavailable' => DeviceFailureKind.unavailable,
        'transient' => DeviceFailureKind.transient,
        _ => DeviceFailureKind.protocol,
      };
      // Never expose remote error bodies, which could contain sensitive data.
      throw DeviceFailure(kind);
    }
    return map['result'];
  }

  static DeviceFailure fromNetwork(NetworkFailure failure) =>
      DeviceFailure(switch (failure.kind) {
        NetworkFailureKind.cancelled => DeviceFailureKind.cancelled,
        NetworkFailureKind.invalidJson => DeviceFailureKind.protocol,
        NetworkFailureKind.configuration => DeviceFailureKind.unavailable,
        NetworkFailureKind.timeout ||
        NetworkFailureKind.transport => DeviceFailureKind.transient,
        NetworkFailureKind.response => switch (failure.statusCode ?? 0) {
          401 => DeviceFailureKind.authentication,
          403 => DeviceFailureKind.authorization,
          404 => DeviceFailureKind.unavailable,
          405 || 501 => DeviceFailureKind.unsupported,
          >= 500 => DeviceFailureKind.transient,
          _ => DeviceFailureKind.protocol,
        },
      });

  static Never fail() => throw const DeviceFailure(DeviceFailureKind.protocol);
  static Map<String, Object?> object(Object? value) {
    if (value is! Map<String, Object?>) fail();
    return value;
  }

  static String text(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) fail();
    return value;
  }

  static String? optionalText(Map<String, Object?> map, String key) =>
      map[key] == null ? null : text(map, key);
  static int? nonnegative(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! int || value < 0) fail();
    return value;
  }

  static T named<T extends Enum>(Iterable<T> values, Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    fail();
  }

  static DeviceCapabilities capabilities(Object? raw) {
    final map = object(raw);
    final values = map['operations'];
    if (values is! List ||
        values.any((v) => v is! String || v.trim().isEmpty)) {
      fail();
    }
    return DeviceCapabilities(values.cast<String>());
  }

  static DeviceStatus status(
    Object? raw, {
    required String expectedDeviceId,
    required bool testOnly,
  }) {
    final map = object(raw);
    final deviceId = text(map, 'device_id');
    // Corroboration inside an existing verified session; never identity proof.
    if (deviceId != expectedDeviceId) {
      throw const DeviceFailure(DeviceFailureKind.identity);
    }
    final battery = nonnegative(map, 'battery_percent');
    final capacity = nonnegative(map, 'storage_bytes');
    final free = nonnegative(map, 'free_bytes');
    if ((battery != null && battery > 100) ||
        (capacity != null && free != null && free > capacity) ||
        (map['charging'] != null && map['charging'] is! bool)) {
      fail();
    }
    return DeviceStatus(
      deviceId: deviceId,
      capabilities: capabilities(map['capabilities']),
      testOnly: testOnly,
      firmwareVersion: optionalText(map, 'firmware_version'),
      batteryPercent: battery,
      charging: map['charging'] as bool?,
      storageBytes: capacity,
      freeBytes: free,
    );
  }

  static RemotePlaybackState playback(Object? raw, {required bool testOnly}) {
    final map = object(raw);
    final position = nonnegative(map, 'position_ms'),
        duration = nonnegative(map, 'duration_ms');
    if (position != null && duration != null && position > duration) fail();
    return RemotePlaybackState(
      phase: named(RemotePlaybackPhase.values, map['phase']),
      testOnly: testOnly,
      songId: optionalText(map, 'song_id'),
      position: position == null ? null : Duration(milliseconds: position),
      duration: duration == null ? null : Duration(milliseconds: duration),
    );
  }

  static RemoteRecordingState recording(Object? raw, {required bool testOnly}) {
    final map = object(raw);
    return RemoteRecordingState(
      phase: named(RemoteRecordingPhase.values, map['phase']),
      recordingId: optionalText(map, 'recording_id'),
      testOnly: testOnly,
    );
  }

  static RecordingMetadata recordingMetadata(
    Object? raw, {
    required bool testOnly,
  }) {
    final map = object(raw);
    final duration = nonnegative(map, 'duration_ms');
    return RecordingMetadata(
      recordingId: text(map, 'recording_id'),
      fileId: optionalText(map, 'file_id'),
      testOnly: testOnly,
      duration: duration == null ? null : Duration(milliseconds: duration),
    );
  }

  static List<RemoteFile> files(Object? raw, {required bool testOnly}) {
    final map = object(raw);
    final values = map['files'];
    if (values is! List) fail();
    return List.unmodifiable(
      values.map((value) {
        final file = object(value);
        return RemoteFile(
          fileId: text(file, 'file_id'),
          name: text(file, 'name'),
          sizeBytes: nonnegative(file, 'size_bytes'),
          testOnly: testOnly,
        );
      }),
    );
  }

  static DownloadJob download(Object? raw, {required bool testOnly}) {
    final map = object(raw);
    return DownloadJob(
      jobId: text(map, 'job_id'),
      phase: named(DownloadPhase.values, map['phase']),
      testOnly: testOnly,
    );
  }

  static void acknowledgement(Object? raw) {
    if (object(raw)['accepted'] != true) fail();
  }
}
