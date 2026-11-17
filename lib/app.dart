import 'package:flutter/material.dart';

import 'frontend/routes/app_router.dart';
import 'frontend/theme/app_theme.dart';

class Mp3ControllerApp extends StatelessWidget {
  const Mp3ControllerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MP3 Controller',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.midnightCrimson,
    onGenerateRoute: AppRouter.onGenerateRoute,
  );
}
