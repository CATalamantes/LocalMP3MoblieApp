import 'package:cta2000/frontend/pages/main_shell.dart';
import 'package:cta2000/frontend/routes/app_router.dart';
import 'package:cta2000/frontend/routes/app_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class StackObserver extends NavigatorObserver {
  final routes = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.add(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.remove(route);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.remove(route);
}

void main() {
  testWidgets(
    'detail primary-tab navigation returns to the original shell without duplicates',
    (tester) async {
      final observer = StackObserver();
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          navigatorObservers: [observer],
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('tab-device')));
        await tester.pumpAndSettle();
        final link = find.byKey(const ValueKey('open-storage'));
        await tester.ensureVisible(link);
        await tester.tap(link);
        await tester.pumpAndSettle();
        final files = find.byKey(const ValueKey('open-files'));
        await tester.ensureVisible(files);
        await tester.tap(files);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('tab-library')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
        expect(find.byType(MainShell), findsOneWidget);
        expect(observer.routes.length, 1);
      }
    },
  );
  testWidgets(
    'direct-entry detail tabs replace their stack with one main destination',
    (tester) async {
      final observer = StackObserver();
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: AppScreen.storage.route,
          onGenerateRoute: AppRouter.onGenerateRoute,
          navigatorObservers: [observer],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab-device')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('screen-device')), findsOneWidget);
      expect(observer.routes.length, 1);
    },
  );
  testWidgets(
    'fullscreen lyrics omits primary navigation and unwinds nested routes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(onGenerateRoute: AppRouter.onGenerateRoute),
      );
      final context = tester.element(find.byType(MainShell));
      Navigator.of(context).pushNamed(AppScreen.songDetails.route);
      await tester.pumpAndSettle();
      final link = find.byKey(const ValueKey('open-lyrics'));
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tab-library')), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('screen-songDetails')), findsOneWidget);
    },
  );
}
