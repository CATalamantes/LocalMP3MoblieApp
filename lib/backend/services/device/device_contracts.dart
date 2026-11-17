import 'json_http_client.dart';
import '../../models/device_models.dart';

enum TransportKind { wifi, ble }

enum DeviceFailureKind {
  unavailable,
  untrusted,
  authorization,
  identity,
  transient,
  unsupported,
  cancelled,
  storage,
  authentication,
  protocol,
  invalidInput,
}

class DeviceFailure implements Exception {
  const DeviceFailure(this.kind);
  final DeviceFailureKind kind;
  @override
  String toString() => 'DeviceFailure(${kind.name})';
}

class DeviceCommandFailure extends DeviceFailure {
  const DeviceCommandFailure(super.kind, {this.outcomeUnknown = false});
  // A lost response must not cause an automatic replay of a changing command.
  final bool outcomeUnknown;
}

/// Opaque provisioning data. Only a verifier can turn it into a trusted record.
class ProvisioningResult {
  const ProvisioningResult({
    required this.deviceId,
    required this.baseUri,
    required this.credential,
    required this.pinnedIdentity,
  });
  final String deviceId, credential, pinnedIdentity;
  final Uri baseUri;
}

class DeviceSettings {
  const DeviceSettings({
    required this.deviceId,
    required this.baseUri,
    this.autoReconnect = true,
  });
  final String deviceId;
  final Uri baseUri;
  final bool autoReconnect;

  Map<String, Object?> toMap() => {
    'deviceId': deviceId,
    'baseUri': baseUri.toString(),
    'autoReconnect': autoReconnect,
  };

  factory DeviceSettings.fromMap(Map<String, Object?> map) => DeviceSettings(
    deviceId: map['deviceId'] as String,
    baseUri: Uri.parse(map['baseUri'] as String),
    autoReconnect: map['autoReconnect'] as bool,
  );
}

class DeviceCredentials {
  const DeviceCredentials({
    required this.deviceId,
    required this.credential,
    required this.pinnedIdentity,
  });
  final String deviceId, credential, pinnedIdentity;
  Map<String, Object?> toMap() => {
    'deviceId': deviceId,
    'credential': credential,
    'pinnedIdentity': pinnedIdentity,
  };
  factory DeviceCredentials.fromMap(Map<String, Object?> map) =>
      DeviceCredentials(
        deviceId: map['deviceId'] as String,
        credential: map['credential'] as String,
        pinnedIdentity: map['pinnedIdentity'] as String,
      );
}

abstract interface class DeviceSettingsStore {
  Future<DeviceSettings?> read();
  Future<void> write(DeviceSettings settings);
  Future<void> clear();
}

abstract interface class CredentialStore {
  Future<DeviceCredentials?> read();
  Future<void> write(DeviceCredentials credentials);
  Future<void> clear();
}

/// A future mobile adapter must use OS-controlled authenticated LE bonding.
abstract interface class BondingProvisioningAdapter {
  Future<PairingWindow?> inspectPairingWindow(
    String deviceId,
    RequestCancellation cancellation,
  );
  Future<ProvisioningResult> provision({
    required String deviceId,
    required String passkey,
    RequestCancellation? cancellation,
  });
}

abstract interface class IdentityAuthorizationVerifier {
  /// Must verify the device identity AND this phone's authorization.
  Future<void> verifyProvisioning(
    ProvisioningResult result, {
    RequestCancellation? cancellation,
  });
}

abstract interface class DeviceDiscoveryAdapter {
  Future<List<NearbyDevice>> discover(RequestCancellation cancellation);
}

abstract interface class DeviceTransferHandle {
  Stream<DeviceTransferSnapshot> get snapshots;
  Future<void> cancel();
}

abstract interface class DeviceTransport {
  TransportKind get kind;
  bool supports(String operation);

  /// Must verify pinned identity and authorization on every connection.
  Future<void> authenticate(
    DeviceSettings settings,
    DeviceCredentials credentials,
    RequestCancellation cancellation,
  );
  Future<Object?> send(
    String operation,
    Object? payload,
    RequestCancellation cancellation,
  );
  Future<void> disconnect();
}

enum ConnectionPhase {
  disconnected,
  connecting,
  reconnecting,
  unavailable,
  failed,
  authenticated,
}

/// Test sessions never become authenticated production hardware sessions.
class ConnectionSnapshot {
  const ConnectionSnapshot(
    this.phase, {
    this.transport,
    this.failure,
    this.testOnly = false,
  });
  final ConnectionPhase phase;
  final TransportKind? transport;
  final DeviceFailureKind? failure;
  final bool testOnly;
  bool get hardwareAuthenticated =>
      !testOnly && phase == ConnectionPhase.authenticated;
}
