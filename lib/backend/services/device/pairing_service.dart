import 'dart:async';

import '../../models/device_models.dart';
import 'device_contracts.dart';
import 'json_http_client.dart';

/// Real BLE, secured provisioning and independent verification are not supplied.
class PairingService {
  PairingService.production({
    required this.settings,
    required this.credentials,
    this.disconnect,
  }) : _bonding = null,
       _verifier = null,
       _discovery = null,
       _clock = DateTime.now,
       testOnly = false;

  PairingService.forTesting({
    required this.settings,
    required this.credentials,
    this.disconnect,
    required BondingProvisioningAdapter bondingAdapter,
    required IdentityAuthorizationVerifier identityVerifier,
    DeviceDiscoveryAdapter? discoveryAdapter,
    DateTime Function()? clock,
  }) : _bonding = bondingAdapter,
       _verifier = identityVerifier,
       _discovery = discoveryAdapter,
       _clock = clock ?? DateTime.now,
       testOnly = true;

  final DeviceSettingsStore settings;
  final CredentialStore credentials;
  final BondingProvisioningAdapter? _bonding;
  final IdentityAuthorizationVerifier? _verifier;
  final DeviceDiscoveryAdapter? _discovery;
  final DateTime Function() _clock;
  final bool testOnly;
  final Future<void> Function()? disconnect;
  RequestCancellation? _operation;
  int _generation = 0;
  bool _disposed = false, _busy = false;
  Future<void> _writes = Future.value();
  Future<void>? _closing;

  void _check(int generation) {
    if (_disposed ||
        generation != _generation ||
        (_operation?.isCancelled ?? false)) {
      throw const DeviceFailure(DeviceFailureKind.cancelled);
    }
  }

  Future<T> _await<T>(Future<T> work, RequestCancellation cancellation) =>
      Future.any([
        work,
        cancellation.cancelled.then<T>(
          (_) => throw const DeviceFailure(DeviceFailureKind.cancelled),
        ),
      ]);

  void cancel() {
    ++_generation;
    _operation?.cancel();
    _operation = null;
  }

  Future<TrustedDeviceSummary?> loadSavedDevice() async {
    if (_disposed) throw const DeviceFailure(DeviceFailureKind.cancelled);
    final generation = _generation;
    try {
      await _writes;
      final saved = await settings.read();
      final secret = await credentials.read();
      if (_disposed || generation != _generation) {
        throw const DeviceFailure(DeviceFailureKind.cancelled);
      }
      if (saved == null && secret == null) return null;
      if (saved == null ||
          secret == null ||
          saved.deviceId.isEmpty ||
          saved.deviceId != secret.deviceId ||
          secret.credential.isEmpty ||
          secret.pinnedIdentity.isEmpty ||
          saved.baseUri.scheme != 'https') {
        throw const DeviceFailure(DeviceFailureKind.untrusted);
      }
      HttpConfiguration(baseUri: saved.baseUri);
      return TrustedDeviceSummary(
        deviceId: saved.deviceId,
        baseUri: saved.baseUri,
        autoReconnect: saved.autoReconnect,
        testOnly: testOnly,
      );
    } on DeviceFailure {
      rethrow;
    } catch (_) {
      throw const DeviceFailure(DeviceFailureKind.storage);
    }
  }

  Future<List<NearbyDevice>> discover() async {
    if (_disposed) throw const DeviceFailure(DeviceFailureKind.cancelled);
    if (!testOnly || _discovery == null || _busy) {
      throw const DeviceFailure(DeviceFailureKind.unavailable);
    }
    cancel();
    final generation = _generation;
    final cancellation = _operation = RequestCancellation();
    final found = await _await(_discovery.discover(cancellation), cancellation);
    _check(generation);
    return List.unmodifiable(found);
  }

  Future<void> pair(String deviceId, String passkey) async {
    if (_disposed) throw const DeviceFailure(DeviceFailureKind.cancelled);
    if (!testOnly || _bonding == null || _verifier == null || _busy) {
      throw const DeviceFailure(DeviceFailureKind.unavailable);
    }
    cancel();
    final generation = _generation;
    final cancellation = _operation = RequestCancellation();
    _busy = true;
    try {
      await _writes;
      _check(generation);
      if (await settings.read() != null || await credentials.read() != null) {
        throw const DeviceFailure(DeviceFailureKind.untrusted);
      }
      _check(generation);
      if (deviceId.isEmpty || !RegExp(r'^\d{6}$').hasMatch(passkey)) {
        throw const DeviceFailure(DeviceFailureKind.authorization);
      }
      final window = await _await(
        _bonding.inspectPairingWindow(deviceId, cancellation),
        cancellation,
      );
      _check(generation);
      if (window == null || !window.isOpenAt(_clock())) {
        throw const DeviceFailure(DeviceFailureKind.unavailable);
      }
      final result = await _await(
        _bonding.provision(
          deviceId: deviceId,
          passkey: passkey,
          cancellation: cancellation,
        ),
        cancellation,
      );
      _check(generation);
      if (!window.isOpenAt(_clock())) {
        throw const DeviceFailure(DeviceFailureKind.unavailable);
      }
      if (result.deviceId != deviceId ||
          result.credential.isEmpty ||
          result.pinnedIdentity.isEmpty ||
          result.baseUri.scheme != 'https') {
        throw const DeviceFailure(DeviceFailureKind.identity);
      }
      HttpConfiguration(baseUri: result.baseUri);
      await _await(
        _verifier.verifyProvisioning(result, cancellation: cancellation),
        cancellation,
      );
      _check(generation);
      final commit = _writes.then((_) async {
        _check(generation);
        if (!window.isOpenAt(_clock())) {
          throw const DeviceFailure(DeviceFailureKind.unavailable);
        }
        try {
          // Writes cannot be abandoned: forget/close drain them before clearing.
          await credentials.write(
            DeviceCredentials(
              deviceId: deviceId,
              credential: result.credential,
              pinnedIdentity: result.pinnedIdentity,
            ),
          );
          _check(generation);
          await settings.write(
            DeviceSettings(deviceId: deviceId, baseUri: result.baseUri),
          );
          _check(generation);
        } catch (error) {
          var cleanupFailed = false;
          try {
            await settings.clear();
          } catch (_) {
            cleanupFailed = true;
          }
          try {
            await credentials.clear();
          } catch (_) {
            cleanupFailed = true;
          }
          if (!cleanupFailed && error is DeviceFailure) rethrow;
          throw const DeviceFailure(DeviceFailureKind.storage);
        }
      });
      _writes = commit.then<void>((_) {}, onError: (Object _, StackTrace _) {});
      await commit;
      _check(generation);
    } on DeviceFailure {
      rethrow;
    } catch (_) {
      throw const DeviceFailure(DeviceFailureKind.storage);
    } finally {
      _busy = false;
    }
  }

  /// Local cleanup only; neither OS bond removal nor remote revocation is claimed.
  Future<void> forget() {
    if (_disposed) {
      return Future.error(const DeviceFailure(DeviceFailureKind.cancelled));
    }
    cancel();
    final cleanup = _writes.then((_) async {
      var failed = false;
      try {
        await disconnect?.call();
      } catch (_) {
        failed = true;
      }
      try {
        await settings.clear();
      } catch (_) {
        failed = true;
      }
      try {
        await credentials.clear();
      } catch (_) {
        failed = true;
      }
      if (failed) throw const DeviceFailure(DeviceFailureKind.storage);
    });
    _writes = cleanup.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return cleanup;
  }

  Future<void> updateSettings(DeviceSettings updated) {
    if (_disposed) {
      return Future.error(const DeviceFailure(DeviceFailureKind.cancelled));
    }
    cancel();
    final generation = _generation;
    final update = _writes.then((_) async {
      _check(generation);
      await disconnect?.call();
      final saved = await settings.read();
      final secret = await credentials.read();
      if (saved == null ||
          secret == null ||
          saved.deviceId != updated.deviceId ||
          secret.deviceId != updated.deviceId ||
          secret.credential.isEmpty ||
          secret.pinnedIdentity.isEmpty ||
          updated.baseUri.scheme != 'https') {
        throw const DeviceFailure(DeviceFailureKind.untrusted);
      }
      HttpConfiguration(baseUri: updated.baseUri);
      _check(generation);
      await settings.write(updated);
    });
    _writes = update.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return update;
  }

  void dispose() {
    if (!_disposed) {
      cancel();
      _disposed = true;
    }
  }

  Future<void> close() => _closing ??= () async {
    dispose();
    await _writes;
  }();
}
