import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';

import '../../controllers/controller_state.dart';
import 'artwork_store.dart';
import 'platform_artwork_store.dart';

class ArtworkFailure extends ControllerFailure {
  const ArtworkFailure(String message)
    : super(ControllerFailureKind.storage, message);
}

class ArtworkDraft {
  ArtworkDraft(Uint8List bytes) : _bytes = Uint8List.fromList(bytes);
  final Uint8List _bytes;
  Uint8List get bytes => Uint8List.fromList(_bytes);
}

/// Draft selection never writes. Only stable managed references enter SQLite.
class ArtworkService {
  ArtworkService({ArtworkStore? store, Future<XFile?> Function()? picker})
    : store = store ?? createArtworkStore(),
      _picker = picker ?? _select;
  final ArtworkStore store;
  final Future<XFile?> Function() _picker;
  Future<void> _tail = Future.value();
  Future<void> get pendingOperations => _tail;
  static Future<XFile?> _select() => openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'PNG or JPEG artwork',
        extensions: ['png', 'jpg', 'jpeg'],
        mimeTypes: ['image/png', 'image/jpeg'],
        uniformTypeIdentifiers: ['public.png', 'public.jpeg'],
      ),
    ],
  );
  Future<T> exclusive<T>(Future<T> Function() action) {
    final work = _tail.then((_) => action());
    _tail = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return work;
  }

  Future<ArtworkDraft?> pick() async {
    try {
      final file = await _picker();
      if (file == null) return null;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const ArtworkFailure('Artwork must be at most 5 MiB');
      }
      final draft = ArtworkDraft(await file.readAsBytes());
      await validate(draft);
      return draft;
    } on ArtworkFailure {
      rethrow;
    } catch (_) {
      throw const ArtworkFailure('Artwork could not be selected');
    }
  }

  Future<void> validate(ArtworkDraft draft) async {
    final bytes = draft.bytes;
    final png =
        bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71;
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    if (bytes.length > 5 * 1024 * 1024 || (!png && !jpeg)) {
      throw const ArtworkFailure('Choose a PNG or JPEG image, at most 5 MiB');
    }
    ui.Codec? codec;
    ui.Image? image;
    try {
      // Encoded ImageDescriptor dimensions are unavailable on Flutter web.
      // Limit decoded output to one pixel above the accepted maximum.
      codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 4097,
        targetHeight: 4097,
        allowUpscaling: false,
      );
      image = (await codec.getNextFrame()).image;
      if (image.width > 4096 || image.height > 4096) {
        throw const ArtworkFailure(
          'Artwork dimensions must not exceed 4096 pixels',
        );
      }
    } on ArtworkFailure {
      rethrow;
    } catch (_) {
      throw const ArtworkFailure('This image cannot be decoded');
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  static String? managedId(String? reference) {
    if (reference == null) return null;
    final match = RegExp(r'^artwork:///([a-f0-9]{32})$').firstMatch(reference);
    return match?.group(1);
  }

  Future<String> save(ArtworkDraft draft) async {
    await validate(draft);
    final id = newMusicIdentifier();
    try {
      await store.write(id, draft.bytes);
    } catch (_) {
      try {
        await store.delete(id);
      } catch (_) {
        /* Never reference a failed write. */
      }
      throw const ArtworkFailure(
        'Artwork could not be stored. Your draft is preserved',
      );
    }
    return 'artwork:///$id';
  }

  Future<Uint8List?> read(String? reference) async {
    final id = managedId(reference);
    return id == null ? null : store.read(id);
  }

  Future<void> delete(String reference) async {
    final id = managedId(reference);
    if (id != null) await store.delete(id);
  }
}
