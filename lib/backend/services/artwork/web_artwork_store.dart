import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'artwork_store.dart';

ArtworkStore createArtworkStore({String namespace = 'cta2000-artwork'}) =>
    WebArtworkStore(namespace);

class WebArtworkStore implements ArtworkStore {
  WebArtworkStore(this.namespace);
  final String namespace;
  Future<web.IDBDatabase>? _database;
  Future<web.IDBDatabase> _open() => _database ??= () {
    final ready = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(namespace, 1);
    request.onupgradeneeded = ((web.Event _) {
      (request.result as web.IDBDatabase).createObjectStore('images');
    }).toJS;
    request.onsuccess = ((web.Event _) => ready.complete(
      request.result as web.IDBDatabase,
    )).toJS;
    request.onerror = ((web.Event _) => ready.completeError(
      StateError('Artwork storage unavailable'),
    )).toJS;
    request.onblocked = ((web.Event _) => ready.completeError(
      StateError('Artwork storage blocked'),
    )).toJS;
    return ready.future;
  }();

  Future<JSAny?> _request(
    String id,
    String mode,
    web.IDBRequest Function(web.IDBObjectStore) operation,
  ) async {
    final db = await _open();
    final complete = Completer<JSAny?>();
    final tx = db.transaction('images'.toJS, mode);
    final request = operation(tx.objectStore('images'));
    tx.oncomplete = ((web.Event _) => complete.complete(request.result)).toJS;
    tx.onabort = ((web.Event _) => complete.completeError(
      StateError('Artwork transaction failed'),
    )).toJS;
    tx.onerror = ((web.Event _) {
      /* abort reports the transaction outcome */
    }).toJS;
    return complete.future;
  }

  @override
  Future<void> write(String id, Uint8List bytes) async {
    await _request(id, 'readwrite', (store) => store.put(bytes.toJS, id.toJS));
  }

  @override
  Future<Uint8List?> read(String id) async {
    final value = await _request(id, 'readonly', (store) => store.get(id.toJS));
    return value == null || value.isUndefined
        ? null
        : (value as JSUint8Array).toDart;
  }

  @override
  Future<void> delete(String id) async {
    await _request(id, 'readwrite', (store) => store.delete(id.toJS));
  }
}
