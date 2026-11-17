import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/music_models.dart';
import '../database/local_music_repository.dart';
import 'audio_service.dart';
import 'audio_source_resolver.dart';

class DevelopmentAudioRegistration {
  DevelopmentAudioRegistration({
    Iterable<String> inserted = const [],
    Iterable<String> existing = const [],
    Iterable<String> missing = const [],
  }) : inserted = List.unmodifiable(inserted),
       existing = List.unmodifiable(existing),
       missing = List.unmodifiable(missing);
  final List<String> inserted, existing, missing;
}

class DevelopmentAudioRegistrar {
  DevelopmentAudioRegistrar(
    this.repository, {
    AssetBundle? bundle,
    AudioSourceResolver? resolver,
    DateTime Function()? clock,
  }) : _bundle = bundle ?? rootBundle,
       _resolver = resolver ?? AudioSourceResolver(bundle: bundle),
       _clock = clock ?? DateTime.now;
  final LocalMusicRepository repository;
  final AssetBundle _bundle;
  final AudioSourceResolver _resolver;
  final DateTime Function() _clock;

  Future<DevelopmentAudioRegistration> register({
    required bool enabled,
    String catalog = 'assets/audio/development_songs.json',
  }) async {
    if (!enabled) return DevelopmentAudioRegistration();
    final candidates = <Song>[];
    final ids = <String>{}, paths = <String>{};
    try {
      final content = jsonDecode(await _bundle.loadString(catalog));
      if (content is! List) {
        throw const FormatException('Expected a catalog array');
      }
      for (final row in content) {
        final map = Map<String, Object?>.from(row as Map);
        final id = map['song_id'] as String;
        final title = map['title'] as String;
        final artist = map['artist_name'] as String;
        final path = map['asset_path'] as String;
        final format = path.toLowerCase().endsWith('.wav') ? 'WAV' : 'MP3';
        final duration = map['duration_ms'] == null
            ? 0
            : map['duration_ms'] as int;
        if (id.trim().isEmpty ||
            title.trim().isEmpty ||
            duration < 0 ||
            !path.startsWith('assets/audio/') ||
            !(path.toLowerCase().endsWith('.mp3') ||
                path.toLowerCase().endsWith('.wav')) ||
            !ids.add(id) ||
            !paths.add(path)) {
          throw const FormatException('Invalid or duplicate catalog entry');
        }
        final uri = Uri(scheme: 'asset', host: '', path: '/$path');
        candidates.add(
          Song(
            songId: id,
            title: title,
            artistName: artist,
            durationMs: duration,
            audioFormat: format,
            filePath: uri.toString(),
            dateAdded: _clock().toUtc(),
          ),
        );
      }
    } catch (error) {
      throw AudioFailure(
        AudioFailureKind.invalidCatalog,
        'Development audio catalog is invalid',
        cause: error,
      );
    }
    final available = <Song>[], missing = <String>[];
    for (final song in candidates) {
      try {
        await _resolver.resolve(song);
        available.add(song);
      } on AudioFailure catch (error) {
        if (error.audioKind != AudioFailureKind.missingSource) rethrow;
        missing.add(song.songId);
      }
    }
    return repository.transaction((tx) async {
      final inserted = <String>[], existing = <String>[];
      for (final song in available) {
        if (await tx.songs.find(song.songId) != null) {
          existing.add(song.songId);
          continue;
        }
        await tx.songs.insert(song);
        inserted.add(song.songId);
      }
      return DevelopmentAudioRegistration(
        inserted: inserted,
        existing: existing,
        missing: missing,
      );
    });
  }
}
