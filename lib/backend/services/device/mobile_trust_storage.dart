import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_contracts.dart';

void _requireMobile() {
  if (kIsWeb ||
      !{
        TargetPlatform.android,
        TargetPlatform.iOS,
      }.contains(defaultTargetPlatform)) {
    throw const DeviceFailure(DeviceFailureKind.unavailable);
  }
}

/// This namespace is never read or written by browser development storage.
class MobileDeviceSettingsStore implements DeviceSettingsStore {
  MobileDeviceSettingsStore({SharedPreferencesAsync? preferencesClient})
    : _preferences = preferencesClient;
  SharedPreferencesAsync? _preferences;
  SharedPreferencesAsync get _client =>
      _preferences ??= SharedPreferencesAsync();
  static const _key = 'cta2000.mobile.trusted-device.settings.v1';

  @override
  Future<DeviceSettings?> read() async {
    _requireMobile();
    final value = await _client.getString(_key);
    return value == null
        ? null
        : DeviceSettings.fromMap(
            Map<String, Object?>.from(jsonDecode(value) as Map),
          );
  }

  @override
  Future<void> write(DeviceSettings settings) async {
    _requireMobile();
    await _client.setString(_key, jsonEncode(settings.toMap()));
  }

  @override
  Future<void> clear() async {
    _requireMobile();
    await _client.remove(_key);
  }
}

class MobileCredentialStore implements CredentialStore {
  MobileCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _key = 'cta2000.mobile.trusted-device.credentials.v1';

  @override
  Future<DeviceCredentials?> read() async {
    _requireMobile();
    final value = await _storage.read(key: _key);
    return value == null
        ? null
        : DeviceCredentials.fromMap(
            Map<String, Object?>.from(jsonDecode(value) as Map),
          );
  }

  @override
  Future<void> write(DeviceCredentials credentials) async {
    _requireMobile();
    await _storage.write(key: _key, value: jsonEncode(credentials.toMap()));
  }

  @override
  Future<void> clear() async {
    _requireMobile();
    await _storage.delete(key: _key);
  }
}
