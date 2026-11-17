import 'dart:io';

import 'audio_service.dart';

Future<void> requireFile(Uri uri) async {
  if (!uri.hasAbsolutePath || uri.host.isNotEmpty) {
    throw AudioFailure(
      AudioFailureKind.unsupportedSource,
      'An absolute local file URI is required',
    );
  }
  if (!await File.fromUri(uri).exists()) {
    throw AudioFailure(
      AudioFailureKind.missingSource,
      'Local audio file is missing',
    );
  }
}
