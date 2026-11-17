import 'package:cta2000/backend/services/device/device_contracts.dart';
import 'package:cta2000/backend/services/device/mobile_trust_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/device_fakes.dart';

// Adapter contract test only: this is not Android/iOS persistence validation.
class FakePreferences implements SharedPreferencesAsync {
  final values = <String, String>{};
  @override
  Future<String?> getString(String key) async => values[key];
  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'mobile preferences contain only non-secret connection settings',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final preferences = FakePreferences();
      final store = MobileDeviceSettingsStore(preferencesClient: preferences);
      expect(await store.read(), isNull);
      await store.write(testSettings);
      expect((await store.read())!.toMap(), testSettings.toMap());
      expect(preferences.values.keys.single, startsWith('cta2000.mobile.'));
      expect(
        preferences.values.values.single,
        isNot(contains(testCredentials.credential)),
      );
      expect(
        preferences.values.values.single,
        isNot(contains('pinnedIdentity')),
      );
      await store.clear();
      expect(await store.read(), isNull);
    },
  );

  test(
    'secure credential adapter delegates to native plugin channel',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final secureValues = <String, String>{};
      messenger.setMockMethodCallHandler(channel, (call) async {
        final arguments = Map<String, Object?>.from(call.arguments as Map);
        final key = arguments['key'] as String;
        expect(key, startsWith('cta2000.mobile.'));
        switch (call.method) {
          case 'write':
            secureValues[key] = arguments['value'] as String;
            return null;
          case 'read':
            return secureValues[key];
          case 'delete':
            secureValues.remove(key);
            return null;
          default:
            throw StateError('Unexpected secure storage method');
        }
      });
      final store = MobileCredentialStore();
      expect(await store.read(), isNull);
      await store.write(testCredentials);
      expect((await store.read())!.toMap(), testCredentials.toMap());
      await store.clear();
      expect(await store.read(), isNull);
    },
  );

  test(
    'unsupported host platforms cannot access mobile trust stores',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final preferences = FakePreferences();
      final settings = MobileDeviceSettingsStore(
        preferencesClient: preferences,
      );
      final credentials = MobileCredentialStore();
      final unavailable = isA<DeviceFailure>().having(
        (e) => e.kind,
        'kind',
        DeviceFailureKind.unavailable,
      );
      await expectLater(settings.read(), throwsA(unavailable));
      await expectLater(settings.write(testSettings), throwsA(unavailable));
      await expectLater(credentials.read(), throwsA(unavailable));
      expect(preferences.values, isEmpty);
    },
  );
}
