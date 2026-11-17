import 'package:flutter/material.dart';

import 'app.dart';
import 'backend/app_dependencies.dart';
import 'backend/services/device/json_http_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpConfiguration? networking;
  String? warning;
  try {
    const baseUrl = String.fromEnvironment('DEVICE_BASE_URL');
    const probePath = String.fromEnvironment('DEVICE_PROBE_PATH');
    const dev = bool.fromEnvironment('DEVICE_LOCAL_DEVELOPMENT');
    networking = baseUrl.isEmpty
        ? null
        : HttpConfiguration(
            baseUri: Uri.parse(baseUrl),
            localDevelopment: dev,
            probePath: probePath.isEmpty ? null : probePath,
          );
  } catch (_) {
    warning = 'Device networking configuration is invalid. Local storage remains available.';
  }
  try {
    final dependencies = await AppDependencies.create(
      httpConfiguration: networking,
    );
    runApp(
      Mp3ControllerApp(dependencies: dependencies, serviceWarning: warning),
    );
  } catch (_) {
    // Keep the approved screens accessible without claiming data is available.
    runApp(const Mp3ControllerApp(initializationFailed: true));
  }
}
