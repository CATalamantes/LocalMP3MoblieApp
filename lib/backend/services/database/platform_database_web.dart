import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'music_database.dart';

Future<MusicDatabase> createPlatformDatabase() async => MusicDatabase(
  factory: databaseFactoryFfiWeb,
  path: 'cta2000-development.db',
);
