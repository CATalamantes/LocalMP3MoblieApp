import 'package:flutter/services.dart';

import '../../models/music_models.dart';
import 'audio_service.dart';
import 'file_source_io.dart'
    if (dart.library.js_interop) 'file_source_web.dart'
    as files;

enum LocalSourceKind { asset, file }

class ResolvedAudioSource {
  const ResolvedAudioSource(this.kind, this.location);
  final LocalSourceKind kind;

  /// An asset bundle key, or an absolute native file URI.
  final String location;
}

class AudioSourceResolver {
  AudioSourceResolver({
    AssetBundle? bundle,
    Future<bool> Function(String)? assetExists,
  }) : _bundle = bundle ?? rootBundle,
       _lookupAsset = assetExists;
  final AssetBundle _bundle;
  final Future<bool> Function(String)? _lookupAsset;

  Future<bool> containsAsset(String key) async {
    if (_lookupAsset != null) return _lookupAsset(key);
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    return manifest.listAssets().contains(key);
  }

  Future<ResolvedAudioSource> resolve(Song song) async {
    final uri = Uri.tryParse(song.filePath);
    if (uri == null ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      throw AudioFailure(
        AudioFailureKind.unsupportedSource,
        'Use an explicit asset or native file URI',
      );
    }
    if (uri.scheme == 'asset' &&
        uri.host.isEmpty &&
        !uri.pathSegments.any(
          (s) => s == '..' || s == '.' || s.contains('/') || s.contains('\\'),
        )) {
      // Uri.path retains percent escapes. AssetManifest keys use decoded names,
      // including the spaces in the owner's existing Track WAV filenames.
      final key = uri.pathSegments.join('/');
      if (!key.startsWith('assets/audio/') ||
          key.length <= 'assets/audio/'.length) {
        throw AudioFailure(
          AudioFailureKind.unsupportedSource,
          'Asset must be inside assets/audio/',
        );
      }
      if (!await containsAsset(key)) {
        throw AudioFailure(
          AudioFailureKind.missingSource,
          'Bundled audio asset is missing: $key',
        );
      }
      return ResolvedAudioSource(LocalSourceKind.asset, key);
    }
    if (uri.scheme == 'file') {
      await files.requireFile(uri);
      return ResolvedAudioSource(LocalSourceKind.file, uri.toString());
    }
    throw AudioFailure(
      AudioFailureKind.unsupportedSource,
      'Remote and ambiguous audio sources are unsupported',
    );
  }
}
