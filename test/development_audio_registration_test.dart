import 'dart:convert';

import 'package:cta2000/backend/controllers/lyrics_controller.dart';
import 'package:cta2000/backend/controllers/library_controller.dart';
import 'package:cta2000/backend/services/audio/audio_service.dart';
import 'package:cta2000/backend/services/audio/audio_source_resolver.dart';
import 'package:cta2000/backend/services/audio/development_audio_registration.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/controller_fixture.dart';

class CatalogBundle extends CachingAssetBundle {
  CatalogBundle(this.catalog);
  String catalog;
  int reads = 0;
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    reads++;
    return catalog;
  }

  @override
  Future<ByteData> load(String key) async =>
      throw UnsupportedError('No audio bytes exist in these tests');
}

void main() {
  late ControllerFixture f;
  late CatalogBundle bundle;
  late DevelopmentAudioRegistrar registrar;
  final row = {
    'song_id': 'dev-fixture',
    'title': 'Configured title',
    'artist_name': 'Configured artist',
    'asset_path': 'assets/audio/owner.mp3',
    'duration_ms': 0,
  };
  setUp(() async {
    f = ControllerFixture();
    await f.open();
    bundle = CatalogBundle('[]');
    registrar = DevelopmentAudioRegistrar(
      f.repository,
      bundle: bundle,
      resolver: AudioSourceResolver(assetExists: (_) async => true),
      clock: f.clock,
    );
  });
  tearDown(() => f.close());

  test('disabled registration and empty catalog insert nothing', () async {
    bundle.catalog = 'not read';
    expect((await registrar.register(enabled: false)).inserted, isEmpty);
    expect(bundle.reads, 0);
    bundle.catalog = '[]';
    expect((await registrar.register(enabled: true)).inserted, isEmpty);
    expect(await f.repository.getSongs(), isEmpty);
  });

  test('stable registration preserves user metadata, lyrics, other songs and source references', () async {
    bundle.catalog = jsonEncode([row]);
    await f.song('unrelated');
    expect((await registrar.register(enabled: true)).inserted, ['dev-fixture']);
    final registered = (await f.repository.songs.find('dev-fixture'))!;
    expect(registered.filePath, 'asset:///assets/audio/owner.mp3');
    expect(registered.durationMs, 0);
    final library = f.own(LibraryController(f.repository));
    final lyrics = f.own(LyricsController(f.repository));
    await library.updateMetadata(
      'dev-fixture',
      const SongMetadataUpdate(title: 'User edited'),
    );
    await lyrics.saveManualLyrics('dev-fixture', 'User lyrics\n歌詞');
    expect((await registrar.register(enabled: true)).existing, ['dev-fixture']);
    expect(
      (await f.repository.songs.find('dev-fixture'))!.title,
      'User edited',
    );
    expect(await f.repository.getLyrics('dev-fixture'), 'User lyrics\n歌詞');
    expect(await f.repository.getSongs(), hasLength(2));
  });

  test('nonexistent fixture is reported, not inserted or fabricated', () async {
    bundle.catalog = jsonEncode([row]);
    final missing = DevelopmentAudioRegistrar(
      f.repository,
      bundle: bundle,
      resolver: AudioSourceResolver(assetExists: (_) async => false),
    );
    final result = await missing.register(enabled: true);
    expect(result.missing, ['dev-fixture']);
    expect(result.inserted, isEmpty);
    expect(await f.repository.getSongs(), isEmpty);
  });

  test(
    'invalid or duplicate catalogs fail before any database mutation',
    () async {
      final invalid = isA<AudioFailure>().having(
        (e) => e.audioKind,
        'kind',
        AudioFailureKind.invalidCatalog,
      );
      for (final catalog in [
        'invalid',
        '{}',
        jsonEncode([row, row]),
        jsonEncode([
          {...row, 'duration_ms': -1},
        ]),
        jsonEncode([
          {...row, 'asset_path': 'Music/01 Track 1.wav'},
        ]),
      ]) {
        bundle.catalog = catalog;
        await expectLater(registrar.register(enabled: true), throwsA(invalid));
        expect(await f.repository.getSongs(), isEmpty);
      }
    },
  );
}
