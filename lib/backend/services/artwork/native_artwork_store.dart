import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'artwork_store.dart';

ArtworkStore createArtworkStore({String namespace = 'cta2000-artwork'}) =>
    NativeArtworkStore(
      () async => Directory(
        path.join((await getApplicationSupportDirectory()).path, namespace),
      ),
    );

/// Only opaque IDs are accepted, never caller-provided paths or original files.
class NativeArtworkStore implements ArtworkStore {
  NativeArtworkStore(this.directory);
  final Future<Directory> Function() directory;
  Future<File> _file(String id) async {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) {
      throw ArgumentError('Invalid artwork ID');
    }
    final root = await directory();
    await root.create(recursive: true);
    return File(path.join(root.path, '$id.image'));
  }

  @override
  Future<void> write(String id, Uint8List bytes) async =>
      (await _file(id)).writeAsBytes(bytes, flush: true);
  @override
  Future<Uint8List?> read(String id) async {
    final file = await _file(id);
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<void> delete(String id) async {
    final file = await _file(id);
    if (await file.exists()) await file.delete();
  }
}
