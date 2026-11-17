// Separate development entry point; no production route or flag enables fixtures.
import 'package:flutter/material.dart';

import '../pages/frontend_page.dart';
import '../pages/main_shell.dart';
import '../routes/app_screen.dart';
import '../routes/frontend_navigation.dart';
import '../theme/app_theme.dart';
import '../widgets/presentation.dart';
import 'frontend_fixtures.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final screen =
      AppScreen.values
          .where((v) => v.name == Uri.base.queryParameters['screen'])
          .firstOrNull ??
      AppScreen.library;
  final mode =
      PresentationMode.values
          .where((v) => v.name == Uri.base.queryParameters['state'])
          .firstOrNull ??
      PresentationMode.ready;
  runApp(FrontendPreviewApp(initialScreen: screen, initialMode: mode));
}

class FrontendPreviewApp extends StatefulWidget {
  const FrontendPreviewApp({
    super.key,
    this.initialScreen = AppScreen.library,
    this.initialMode = PresentationMode.ready,
  });
  final AppScreen initialScreen;
  final PresentationMode initialMode;
  @override
  State<FrontendPreviewApp> createState() => _FrontendPreviewAppState();
}

class _FrontendPreviewAppState extends State<FrontendPreviewApp> {
  final _navigator = GlobalKey<NavigatorState>();
  late AppScreen _screen = widget.initialScreen;
  late PresentationMode _mode = widget.initialMode;
  void _show({AppScreen? screen, PresentationMode? mode}) {
    setState(() {
      _screen = screen ?? _screen;
      _mode = mode ?? _mode;
    });
    _navigator.currentState!.pushNamedAndRemoveUntil(
      _screen.route,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'CTA2000 Design Preview',
    theme: AppTheme.midnightCrimson,
    navigatorKey: _navigator,
    initialRoute: _screen.route,
    onGenerateRoute: (settings) {
      final screen =
          AppScreen.values.where((v) => v.route == settings.name).firstOrNull ??
          AppScreen.library;
      final data = frontendFixture(_mode);
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => AppScreen.mainScreens.contains(screen)
            ? MainShell(initialScreen: screen, presentation: data)
            : FrontendPage(
                screen: screen,
                arguments: FrontendRouteArguments(
                  presentation: data,
                  origin: settings.arguments is FrontendRouteArguments
                      ? (settings.arguments as FrontendRouteArguments).origin
                      : null,
                ),
              ),
      );
    },
    builder: (context, child) => Column(
      children: [
        Material(
          color: AppTheme.blue,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'DESIGN PREVIEW · SAMPLE DATA · NO SERVICES',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton<AppScreen>(
                    tooltip: 'Preview screen',
                    icon: const Icon(Icons.dashboard_outlined),
                    itemBuilder: (_) => [
                      for (final screen in AppScreen.values)
                        PopupMenuItem(value: screen, child: Text(screen.title)),
                    ],
                    onSelected: (value) => _show(screen: value),
                  ),
                  PopupMenuButton<PresentationMode>(
                    tooltip: 'Preview state',
                    icon: const Icon(Icons.layers_outlined),
                    itemBuilder: (_) => [
                      for (final mode in PresentationMode.values)
                        PopupMenuItem(value: mode, child: Text(mode.name)),
                    ],
                    onSelected: (value) => _show(mode: value),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child ?? const SizedBox.shrink()),
      ],
    ),
  );
}
