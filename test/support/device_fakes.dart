import 'package:cta2000/backend/services/device/device_contracts.dart';
import 'package:cta2000/backend/services/device/json_http_client.dart';
import 'package:cta2000/backend/models/device_models.dart';

final testSettings = DeviceSettings(
  deviceId: 'test-only-device',
  baseUri: Uri.parse('https://device.invalid:8443/api/'),
);
const testCredentials = DeviceCredentials(
  deviceId: 'test-only-device',
  credential: 'test-only-credential',
  pinnedIdentity: 'test-only-pin',
);

class MemorySettings implements DeviceSettingsStore {
  DeviceSettings? value;
  bool failWrite = false;
  bool failClear = false;
  int reads = 0;
  @override
  Future<DeviceSettings?> read() async {
    reads++;
    return value;
  }

  @override
  Future<void> write(DeviceSettings settings) async {
    if (failWrite) throw StateError('test write failure');
    value = settings;
  }

  @override
  Future<void> clear() async {
    if (failClear) throw StateError('test clear failure');
    value = null;
  }
}

class MemoryCredentials implements CredentialStore {
  DeviceCredentials? value;
  bool failWrite = false;
  @override
  Future<DeviceCredentials?> read() async => value;
  @override
  Future<void> write(DeviceCredentials credentials) async {
    if (failWrite) throw StateError('test write failure');
    value = credentials;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class FakeProvisioning implements BondingProvisioningAdapter {
  DeviceFailureKind? failure;
  int calls = 0;
  @override
  Future<PairingWindow?> inspectPairingWindow(
    String deviceId,
    RequestCancellation cancellation,
  ) async => PairingWindow(
    open: true,
    expiresAt: DateTime.now().add(const Duration(minutes: 2)),
  );
  @override
  Future<ProvisioningResult> provision({
    required String deviceId,
    required String passkey,
    RequestCancellation? cancellation,
  }) async {
    calls++;
    if (failure != null) throw DeviceFailure(failure!);
    return ProvisioningResult(
      deviceId: deviceId,
      baseUri: testSettings.baseUri,
      credential: testCredentials.credential,
      pinnedIdentity: testCredentials.pinnedIdentity,
    );
  }
}

class FakeVerifier implements IdentityAuthorizationVerifier {
  DeviceFailureKind? failure;
  int calls = 0;
  @override
  Future<void> verifyProvisioning(
    ProvisioningResult result, {
    RequestCancellation? cancellation,
  }) async {
    calls++;
    if (failure != null) throw DeviceFailure(failure!);
  }
}

class FakeTransport implements DeviceTransport {
  FakeTransport(this.kind);
  @override
  final TransportKind kind;
  int attempts = 0, sends = 0, disconnects = 0;
  Set<String> operations = {'status'};
  Future<void> Function(int attempt, RequestCancellation cancellation)?
  onAuthenticate;
  DeviceFailureKind? sendFailure;
  @override
  bool supports(String operation) => operations.contains(operation);
  @override
  Future<void> authenticate(
    DeviceSettings settings,
    DeviceCredentials credentials,
    RequestCancellation cancellation,
  ) async {
    attempts++;
    await onAuthenticate?.call(attempts, cancellation);
  }

  @override
  Future<Object?> send(
    String operation,
    Object? payload,
    RequestCancellation cancellation,
  ) async {
    sends++;
    if (sendFailure != null) throw DeviceFailure(sendFailure!);
    return {'testOnly': true};
  }

  @override
  Future<void> disconnect() async {
    disconnects++;
  }
}
