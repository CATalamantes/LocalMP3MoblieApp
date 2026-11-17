import 'package:flutter/material.dart';

import '../../backend/controllers/navigation_controller.dart';
import '../routes/app_screen.dart';
import '../routes/frontend_navigation.dart';
import '../widgets/design_widgets.dart';
import '../widgets/presentation.dart';
import '../widgets/application_binding.dart';
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
  void _select(int index) {
    _controller.selectTab(index);
    final actions = ApplicationScope.of(context);
    if (index == 3 && actions != null) {
      actions.detailSongId = null;
      actions.quietly(actions.loadStatistics);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => PageNavigationScope(
      origin: NavigationOrigin(
        ModalRoute.of(context)!,
        _controller,
        onSelect: _select,
      ),
      presentation: _data,
      child: Builder(
        builder: (context) => ScreenFrame(
          screen: _controller.screen,
          main: true,
          selectedIndex: _controller.selectedIndex,
          onSelect: _select,
          onSearch: () => setState(() => _search = true),
          body: IndexedStack(
            index: _controller.selectedIndex,
            children: [
              for (final screen in AppScreen.mainScreens)
                BoundContent(
                  screen: screen,
                  fallback: _data,
                  builder: (context, data) =>
                      screenContent(screen, data, searchExpanded: _search),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
