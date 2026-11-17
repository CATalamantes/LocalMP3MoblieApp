import 'package:flutter/material.dart';

import '../../backend/controllers/navigation_controller.dart';
import '../widgets/presentation.dart';
import 'app_screen.dart';

class NavigationOrigin {
  const NavigationOrigin(this.route, this.controller, {this.onSelect});
  final Route<dynamic> route;
  final NavigationController controller;
  final ValueChanged<int>? onSelect;
}

class FrontendRouteArguments {
  const FrontendRouteArguments({
    this.origin,
    this.presentation,
    this.songId,
    this.playlistId,
  });
  final NavigationOrigin? origin;
  final ScreenPresentation? presentation;
  final String? songId, playlistId;
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
  String? songId,
  String? playlistId,
}) {
  final scope = PageNavigationScope.of(context);
  Navigator.of(context).pushNamed(
    screen.route,
    arguments: FrontendRouteArguments(
      origin: scope?.origin,
      presentation: presentation ?? scope?.presentation,
      songId:
          songId ??
          presentation?.song?.songId ??
          scope?.presentation.song?.songId,
      playlistId:
          playlistId ??
          presentation?.playlist?.playlistId ??
          scope?.presentation.playlist?.playlistId,
    ),
  );
}

void selectPrimary(BuildContext context, int index) {
  final origin = PageNavigationScope.of(context)?.origin;
  if (origin != null && origin.route.isActive) {
    Navigator.of(context).popUntil((route) => identical(route, origin.route));
    (origin.onSelect ?? origin.controller.selectTab)(index);
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
