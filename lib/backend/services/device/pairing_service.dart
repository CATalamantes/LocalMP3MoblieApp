import 'device_contracts.dart';
import 'json_http_client.dart';

/// No production capability switch: until real adapters exist this service is
/// unavailable in production. The test constructor always marks test mode.
class PairingService {
  PairingService.production({
    required this.settings,
    required this.credentials,
    this.disconnect,
  }) : _bonding = null,
       _verifier = null,
       testOnly = false;

  PairingService.forTesting({
    required this.settings,
    required this.credentials,
    this.disconnect,
    required BondingProvisioningAdapter bondingAdapter,
    required IdentityAuthorizationVerifier identityVerifier,
  }) : _bonding = bondingAdapter,
       _verifier = identityVerifier,
       testOnly = true;

  final DeviceSettingsStore settings;
  final CredentialStore credentials;
  final BondingProvisioningAdapter? _bonding;
  final IdentityAuthorizationVerifier? _verifier;
  final bool testOnly;
  final Future<void> Function()? disconnect;
  bool _busy = false;

  Future<void> pair(String deviceId, String passkey) async {
    if (!testOnly || _bonding == null || _verifier == null) {
      throw const DeviceFailure(DeviceFailureKind.unavailable);
    }
    if (_busy) throw const DeviceFailure(DeviceFailureKind.unavailable);
    _busy = true;
    try {
      if (await settings.read() != null || await credentials.read() != null) {
        throw const DeviceFailure(DeviceFailureKind.untrusted);
      }
      if (deviceId.isEmpty || !RegExp(r'^\d{6}$').hasMatch(passkey)) {
        throw const DeviceFailure(DeviceFailureKind.authorization);
      }
      final result = await _bonding.provision(
        deviceId: deviceId,
        passkey: passkey,
      );
      if (result.deviceId != deviceId ||
          result.credential.isEmpty ||
          result.pinnedIdentity.isEmpty ||
          result.baseUri.scheme != 'https') {
        throw const DeviceFailure(DeviceFailureKind.identity);
      }
      HttpConfiguration(baseUri: result.baseUri);
      await _verifier.verifyProvisioning(result);
      try {
        await credentials.write(
          DeviceCredentials(
            deviceId: deviceId,
            credential: result.credential,
            pinnedIdentity: result.pinnedIdentity,
          ),
        );
        await settings.write(
          DeviceSettings(deviceId: deviceId, baseUri: result.baseUri),
        );
      } catch (_) {
        // Remove the settings commit marker first. Reconnect also requires BOTH
        // matching records, so a partial secure-store write cannot grant trust.
        try {
          await settings.clear();
        } catch (_) {
          /* fail closed below */
        }
        try {
          await credentials.clear();
        } catch (_) {
          /* caller must retry cleanup */
        }
        throw const DeviceFailure(DeviceFailureKind.storage);
      }
    } finally {
      _busy = false;
    }
  }

  /// Local forgetting never claims that remote authorization was revoked.
  /// Native bond removal and remote revocation need the future real adapter.
  Future<void> forget() async {
    if (_busy) throw const DeviceFailure(DeviceFailureKind.unavailable);
    _busy = true;
    try {
      Object? failure;
      try {
        await disconnect?.call();
      } catch (error) {
        failure = error;
      }
      try {
        await settings.clear();
      } catch (error) {
        failure = error;
      }
      try {
        await credentials.clear();
      } catch (error) {
        failure = error;
      }
      if (failure != null) throw const DeviceFailure(DeviceFailureKind.storage);
    } finally {
      _busy = false;
    }
  }
}
