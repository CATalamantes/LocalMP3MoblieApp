import 'audio_service.dart';

Future<void> requireFile(Uri uri) async => throw AudioFailure(
  AudioFailureKind.unsupportedSource,
  'Browser playback cannot access native file URIs',
);
