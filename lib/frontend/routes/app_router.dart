import 'package:flutter/material.dart';

import '../pages/main_shell.dart';
import '../pages/frontend_page.dart';
import 'frontend_navigation.dart';
import 'app_screen.dart';

abstract final class AppRouter {
  static Route<void> onGenerateRoute(RouteSettings settings) {
    final screen = AppScreen.values
        .where((screen) => screen.route == settings.name)
        .firstOrNull;
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) {
        if (settings.name == '/') return const MainShell();
        if (screen == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Page unavailable')),
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  AppScreen.library.route,
                  (route) => false,
                ),
                child: const Text('Return to Library'),
              ),
            ),
          );
        }
        if (AppScreen.mainScreens.contains(screen)) {
          return MainShell(initialScreen: screen);
        }
        return FrontendPage(
          screen: screen,
          arguments: settings.arguments is FrontendRouteArguments
              ? settings.arguments as FrontendRouteArguments
              : null,
        );
      },
    );
  }
}
