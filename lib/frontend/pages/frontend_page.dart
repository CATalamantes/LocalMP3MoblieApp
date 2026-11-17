import 'package:flutter/material.dart';

import '../routes/app_screen.dart';
import '../routes/frontend_navigation.dart';
import '../widgets/design_widgets.dart';
import '../widgets/presentation.dart';
import 'capture_pages.dart';
import 'device_pages.dart';
import 'library_pages.dart';
import 'playback_pages.dart';
import 'statistics_page.dart';

Widget screenContent(
  AppScreen screen,
  ScreenPresentation data, {
  bool searchExpanded = false,
}) => switch (screen) {
  AppScreen.library => LibraryPage(data: data, searchExpanded: searchExpanded),
  AppScreen.playlist => PlaylistPage(data: data),
  AppScreen.nowPlaying => NowPlayingPage(data: data),
  AppScreen.songDetails => SongDetailsPage(data: data),
  AppScreen.lyrics => FullscreenLyricsPage(data: data),
  AppScreen.addMusic => AddMusicPage(data: data),
  AppScreen.record => RecordPage(data: data),
  AppScreen.saveRecording => SaveRecordingPage(data: data),
  AppScreen.device => DeviceOverviewPage(data: data),
  AppScreen.connections => ConnectionsPage(data: data),
  AppScreen.sync => MusicSyncPage(data: data),
  AppScreen.storage => StoragePage(data: data),
  AppScreen.files => FileManagerPage(data: data),
  AppScreen.bluetoothAudio => BluetoothAudioPage(data: data),
  AppScreen.batteryDisplay => BatteryDisplayPage(data: data),
  AppScreen.aboutDevice => AboutDevicePage(data: data),
  AppScreen.statistics => StatisticsPage(data: data),
};

class FrontendPage extends StatelessWidget {
  const FrontendPage({super.key, required this.screen, this.arguments});
  final AppScreen screen;
  final FrontendRouteArguments? arguments;
  @override
  Widget build(BuildContext context) {
    final data = arguments?.presentation ?? ScreenPresentation();
    return PageNavigationScope(
      origin: arguments?.origin,
      presentation: data,
      child: Builder(
        builder: (context) => ScreenFrame(
          screen: screen,
          body: screenContent(screen, data),
          selectedIndex:
              arguments?.origin?.controller.selectedIndex ??
              primaryIndex(screen),
          onSelect: (index) => selectPrimary(context, index),
        ),
      ),
    );
  }
}
