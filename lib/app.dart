import 'package:flutter/material.dart';

import 'backend/app_dependencies.dart';
import 'frontend/routes/app_router.dart';
import 'frontend/theme/app_theme.dart';

class Mp3ControllerApp extends StatefulWidget {
  const Mp3ControllerApp({
    super.key,
    this.dependencies,
    this.initializationFailed = false,
    this.serviceWarning,
  });

  final AppDependencies? dependencies;
  final bool initializationFailed;
  final String? serviceWarning;

  @override
  State<Mp3ControllerApp> createState() => _Mp3ControllerAppState();
}

class _Mp3ControllerAppState extends State<Mp3ControllerApp> {
  @override
  void dispose() {
    // Production dependencies are owned by the app; test services stay injected.
    widget.dependencies?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MP3 Controller',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.midnightCrimson,
    onGenerateRoute: AppRouter.onGenerateRoute,
    builder: (context, child) => Column(
      children: [
        if (widget.initializationFailed)
          const SafeArea(
            bottom: false,
            child: Material(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Local services could not initialize. Restart to retry; saved data has not been reset.',
                ),
              ),
            ),
          ),
        if (widget.serviceWarning != null)
          SafeArea(
            bottom: false,
            child: Material(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(widget.serviceWarning!),
              ),
            ),
          ),
        Expanded(child: child ?? const SizedBox.shrink()),
      ],
    ),
  );
}
