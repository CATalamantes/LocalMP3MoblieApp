import 'package:flutter/foundation.dart';

import '../../frontend/routes/app_screen.dart';

/// Owns main-destination selection; detail navigation uses Flutter Navigator.
class NavigationController extends ChangeNotifier {
  NavigationController({AppScreen initialScreen = AppScreen.library})
    : _selectedIndex = AppScreen.mainScreens.indexOf(initialScreen) {
    if (_selectedIndex < 0) {
      throw ArgumentError.value(initialScreen, 'initialScreen');
    }
  }

  int _selectedIndex;
  int get selectedIndex => _selectedIndex;
  AppScreen get screen => AppScreen.mainScreens[_selectedIndex];

  void selectTab(int index) {
    RangeError.checkValidIndex(index, AppScreen.mainScreens);
    if (_selectedIndex == index) return;
    _selectedIndex = index;
    notifyListeners();
  }
}
