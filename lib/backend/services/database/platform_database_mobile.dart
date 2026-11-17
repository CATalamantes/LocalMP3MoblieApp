import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'music_database.dart';

Future<MusicDatabase> createPlatformDatabase() async => MusicDatabase(
  factory: databaseFactory,
  path: path.join(await getDatabasesPath(), 'cta2000.db'),
);
