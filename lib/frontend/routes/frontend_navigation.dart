import 'package:flutter/material.dart';

import '../../backend/controllers/navigation_controller.dart';
import '../widgets/presentation.dart';
import 'app_screen.dart';

class NavigationOrigin {
  const NavigationOrigin(this.route, this.controller);
  final Route<dynamic> route;
  final NavigationController controller;
}

class FrontendRouteArguments {
  const FrontendRouteArguments({this.origin, this.presentation});
  final NavigationOrigin? origin;
  final ScreenPresentation? presentation;
}

class PageNavigationScope extends InheritedWidget {
  const PageNavigationScope({
    super.key,
    required super.child,
    required this.presentation,
    this.origin,
  });
  final NavigationOrigin? origin;
  final ScreenPresentation presentation;
  static PageNavigationScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageNavigationScope>();
  @override
  bool updateShouldNotify(PageNavigationScope oldWidget) =>
      origin != oldWidget.origin || presentation != oldWidget.presentation;
}

void openScreen(
  BuildContext context,
  AppScreen screen, {
  ScreenPresentation? presentation,
}) {
  final scope = PageNavigationScope.of(context);
  Navigator.of(context).pushNamed(
    screen.route,
    arguments: FrontendRouteArguments(
      origin: scope?.origin,
      presentation: presentation ?? scope?.presentation,
    ),
  );
}

void selectPrimary(BuildContext context, int index) {
  final origin = PageNavigationScope.of(context)?.origin;
  if (origin != null && origin.route.isActive) {
    Navigator.of(context).popUntil((route) => identical(route, origin.route));
    origin.controller.selectTab(index);
  } else {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppScreen.mainScreens[index].route, (_) => false);
  }
}

int primaryIndex(AppScreen screen) => switch (screen) {
  AppScreen.addMusic || AppScreen.record || AppScreen.saveRecording => 1,
  AppScreen.device ||
  AppScreen.connections ||
  AppScreen.sync ||
  AppScreen.storage ||
  AppScreen.files ||
  AppScreen.bluetoothAudio ||
  AppScreen.batteryDisplay ||
  AppScreen.aboutDevice => 2,
  AppScreen.statistics => 3,
  _ => 0,
};
