import 'dart:typed_data';

abstract interface class ArtworkStore {
  Future<void> write(String id, Uint8List bytes);
  Future<Uint8List?> read(String id);
  Future<void> delete(String id);
}
