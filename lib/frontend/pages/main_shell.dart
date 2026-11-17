import 'package:flutter/material.dart';

import '../../backend/controllers/navigation_controller.dart';
import '../routes/app_screen.dart';
import '../widgets/preview_widgets.dart';
import 'placeholder_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialScreen = AppScreen.library});

  final AppScreen initialScreen;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final NavigationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = NavigationController(initialScreen: widget.initialScreen);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(_controller.screen.title)),
      body: SafeArea(
        child: IndexedStack(
          index: _controller.selectedIndex,
          children: [
            for (final screen in AppScreen.mainScreens)
              PlaceholderContent(screen: screen),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayerPreview(),
            NavigationBar(
              selectedIndex: _controller.selectedIndex,
              onDestinationSelected: _controller.selectTab,
              destinations: const [
                NavigationDestination(
                  key: ValueKey('tab-library'),
                  icon: Icon(Icons.library_music_outlined),
                  label: 'Library',
                ),
                NavigationDestination(
                  key: ValueKey('tab-addMusic'),
                  icon: Icon(Icons.add_circle_outline),
                  label: 'Add Music',
                ),
                NavigationDestination(
                  key: ValueKey('tab-device'),
                  icon: Icon(Icons.speaker_outlined),
                  label: 'Device',
                ),
                NavigationDestination(
                  key: ValueKey('tab-statistics'),
                  icon: Icon(Icons.bar_chart),
                  label: 'Statistics',
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
