import 'package:flutter/material.dart';

import '../../backend/controllers/navigation_controller.dart';
import '../routes/app_screen.dart';
import '../routes/frontend_navigation.dart';
import '../widgets/design_widgets.dart';
import '../widgets/presentation.dart';
import 'frontend_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.initialScreen = AppScreen.library,
    this.presentation,
  });
  final AppScreen initialScreen;
  final ScreenPresentation? presentation;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final _controller = NavigationController(
    initialScreen: widget.initialScreen,
  );
  late final _data = widget.presentation ?? ScreenPresentation();
  bool _search = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => PageNavigationScope(
      origin: NavigationOrigin(ModalRoute.of(context)!, _controller),
      presentation: _data,
      child: Builder(
        builder: (context) => ScreenFrame(
          screen: _controller.screen,
          main: true,
          selectedIndex: _controller.selectedIndex,
          onSelect: _controller.selectTab,
          onSearch: () => setState(() => _search = true),
          body: IndexedStack(
            index: _controller.selectedIndex,
            children: [
              for (final screen in AppScreen.mainScreens)
                screenContent(screen, _data, searchExpanded: _search),
            ],
          ),
        ),
      ),
    ),
  );
}
