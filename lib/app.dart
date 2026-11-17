import 'package:flutter/material.dart';

import 'backend/app_dependencies.dart';
import 'frontend/routes/app_router.dart';
import 'frontend/theme/app_theme.dart';
import 'frontend/widgets/application_binding.dart';

class Mp3ControllerApp extends StatefulWidget {
  const Mp3ControllerApp({
    super.key,
    this.dependencies,
    this.initializationFailed = false,
    this.serviceWarning,
    this.ownsDependencies = true,
    this.navigatorKey,
  });

  final AppDependencies? dependencies;
  final bool initializationFailed;
  final String? serviceWarning;
  final bool ownsDependencies;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<Mp3ControllerApp> createState() => _Mp3ControllerAppState();
}

class _Mp3ControllerAppState extends State<Mp3ControllerApp> {
  @override
  void didUpdateWidget(Mp3ControllerApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dependencies != widget.dependencies &&
        oldWidget.ownsDependencies) {
      oldWidget.dependencies?.close();
    }
  }

  @override
  void dispose() {
    // Injected tests can explicitly retain ownership for teardown/reopening.
    if (widget.ownsDependencies) widget.dependencies?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MP3 Controller',
    navigatorKey: widget.navigatorKey,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.midnightCrimson,
    onGenerateRoute: AppRouter.onGenerateRoute,
    navigatorObservers: [frontendRouteObserver],
    builder: (context, child) {
      final content = Column(
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
      );
      return widget.dependencies == null
          ? content
          : ApplicationBinding(
              key: ObjectKey(widget.dependencies),
              dependencies: widget.dependencies!,
              child: content,
            );
    },
  );
}
