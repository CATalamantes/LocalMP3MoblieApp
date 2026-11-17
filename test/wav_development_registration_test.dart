import 'dart:convert';

import 'package:cta2000/backend/services/audio/audio_source_resolver.dart';
import 'package:cta2000/backend/services/audio/audio_service.dart';
import 'package:cta2000/backend/models/music_models.dart';
import 'package:cta2000/backend/services/audio/development_audio_registration.dart';
import 'package:flutter_test/flutter_test.dart';

import 'development_audio_registration_test.dart' show CatalogBundle;
import 'support/controller_fixture.dart';

void main() {
  test('encoded filenames resolve to actual asset keys while encoded path traversal stays unsupported', () async {
    Song song(String path) => Song(
      songId: 'wav-source',
      title: 'Track 1',
      artistName: 'Unknown artist',
      durationMs: 238146,
      audioFormat: 'WAV',
      filePath: path,
      dateAdded: DateTime.utc(2026),
    );
    final resolver = AudioSourceResolver(
      assetExists: (key) async => key == 'assets/audio/01 Track 1.wav',
    );
    final source = await resolver.resolve(
      song('asset:///assets/audio/01%20Track%201.wav'),
    );
    expect(source.location, 'assets/audio/01 Track 1.wav');
    await expectLater(
      resolver.resolve(song('asset:///assets/audio/%2e%2e%2Foutside.wav')),
      throwsA(
        isA<AudioFailure>().having(
          (e) => e.audioKind,
          'kind',
          AudioFailureKind.unsupportedSource,
        ),
      ),
    );
  });
  test('existing WAV metadata registers stable songs with honest format and encoded asset references', () async {
    final fixture = ControllerFixture();
    await fixture.open();
    try {
      final registrar = DevelopmentAudioRegistrar(
        fixture.repository,
        bundle: CatalogBundle(
          jsonEncode([
            {
              'song_id': 'dev-wav-test',
              'title': 'Track 1',
              'artist_name': 'Unknown artist',
              'asset_path': 'assets/audio/01 Track 1.wav',
              'duration_ms': 238146,
            },
          ]),
        ),
        resolver: AudioSourceResolver(assetExists: (_) async => true),
      );
      expect((await registrar.register(enabled: false)).inserted, isEmpty);
      expect((await registrar.register(enabled: true)).inserted, [
        'dev-wav-test',
      ]);
      final song = (await fixture.repository.songs.find('dev-wav-test'))!;
      expect(song.audioFormat, 'WAV');
      expect(song.filePath, 'asset:///assets/audio/01%20Track%201.wav');
      expect(song.durationMs, 238146);
      expect((await registrar.register(enabled: true)).existing, [
        'dev-wav-test',
      ]);
      expect(await fixture.repository.getSongs(), hasLength(1));
    } finally {
      await fixture.close();
    }
  });

  test(
    'missing staged WAVs are reported without inserting nonexistent songs',
    () async {
      final fixture = ControllerFixture();
      await fixture.open();
      try {
        final registrar = DevelopmentAudioRegistrar(
          fixture.repository,
          bundle: CatalogBundle(
            jsonEncode([
              {
                'song_id': 'missing-wav',
                'title': 'Track 1',
                'artist_name': 'Unknown artist',
                'asset_path': 'assets/audio/01 Track 1.wav',
              },
            ]),
          ),
          resolver: AudioSourceResolver(assetExists: (_) async => false),
        );
        final result = await registrar.register(enabled: true);
        expect(result.missing, ['missing-wav']);
        expect(await fixture.repository.getSongs(), isEmpty);
      } finally {
        await fixture.close();
      }
    },
  );
}
