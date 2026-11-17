// Isolated development entry point; intentionally absent from production routes.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../backend/app_dependencies.dart';
import '../theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final dependencies = await AppDependencies.create();
    runApp(LocalPlaybackHarness(dependencies: dependencies));
  } catch (error) {
    runApp(
      MaterialApp(
        theme: AppTheme.midnightCrimson,
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Development services could not initialize: $error'),
            ),
          ),
        ),
      ),
    );
  }
}

class LocalPlaybackHarness extends StatefulWidget {
  const LocalPlaybackHarness({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<LocalPlaybackHarness> createState() => _LocalPlaybackHarnessState();
}

class _LocalPlaybackHarnessState extends State<LocalPlaybackHarness> {
  final _seek = TextEditingController(text: '0');
  String? _error;
  int _initialIndex = 0;
  List<String> get _ids => [
    ...widget.dependencies.developmentAudio.inserted,
    ...widget.dependencies.developmentAudio.existing,
  ];

  Future<void> _run(FutureOr<void> Function() operation) async {
    try {
      await operation();
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    _seek.dispose();
    unawaited(widget.dependencies.close().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = widget.dependencies.playback;
    final available = _ids.isNotEmpty;
    return MaterialApp(
      title: 'Development Local Playback',
      theme: AppTheme.midnightCrimson,
      home: Scaffold(
        appBar: AppBar(title: const Text('Local Playback — Development Only')),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: playback,
            builder: (context, _) {
              final data = playback.state.data;
              Widget button(
                String label,
                String key,
                FutureOr<void> Function() action,
              ) => OutlinedButton(
                key: ValueKey(key),
                onPressed: available ? () => _run(action) : null,
                child: Text(label),
              );
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      available
                          ? 'Manual audio verification required'
                          : 'Awaiting MP3 File',
                      key: const ValueKey('audio-fixture-status'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    if (!available)
                      const Text(
                        'Real MP3 playback: Not Tested — Awaiting MP3 File.\n'
                        'Place your own MP3 in assets/audio/, update development_songs.json, '
                        'and launch this target with ENABLE_DEVELOPMENT_AUDIO=true. '
                        'No audio is generated, downloaded, or converted.',
                      ),
                    if (widget.dependencies.developmentAudio.missing.isNotEmpty)
                      Text(
                        'Missing assets: ${widget.dependencies.developmentAudio.missing.join(', ')}',
                      ),
                    if (available)
                      DropdownButton<int>(
                        value: _initialIndex,
                        isExpanded: true,
                        items: [
                          for (var i = 0; i < _ids.length; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text(
                                _ids[i],
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _initialIndex = value ?? 0),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Song: ${data.selectedSong?.title ?? 'None'}\n'
                      'Queue index: ${data.queueIndex ?? 'None'}\n'
                      'Processing: ${data.audio.phase.name}\n'
                      'Play intent: ${data.playIntent}\n'
                      'Engine play flag: ${data.audio.playing}\n'
                      'Playing and ready: ${data.isPlaying}\n'
                      'Position: ${data.position.inMilliseconds} ms\n'
                      'Duration: ${data.duration?.inMilliseconds.toString() ?? 'Unknown'} ms',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        button(
                          'Load queue',
                          'dev-load',
                          () => playback.setQueue(
                            _ids,
                            initialIndex: _initialIndex,
                          ),
                        ),
                        button('Play', 'dev-play', playback.play),
                        button('Pause', 'dev-pause', playback.pause),
                        button('Resume', 'dev-resume', playback.resume),
                        button('Stop', 'dev-stop', playback.stop),
                        button('Previous', 'dev-previous', () async {
                          await playback.previous();
                        }),
                        button('Next', 'dev-next', () async {
                          await playback.next();
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _seek,
                      enabled: available,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Seek position in seconds',
                      ),
                    ),
                    button('Seek', 'dev-seek', () async {
                      final seconds = double.tryParse(_seek.text);
                      if (seconds == null || !seconds.isFinite) {
                        throw const FormatException('Enter a valid seek time');
                      }
                      await playback.seek(
                        Duration(milliseconds: (seconds * 1000).round()),
                      );
                    }),
                    if (_error != null) Text(_error!),
                    if (playback.state.error != null)
                      Text(playback.state.error.toString()),
                    if (data.audioError != null)
                      Text(data.audioError.toString()),
                    const SizedBox(height: 12),
                    const Text(
                      'Development controls only. Start playback with a user gesture. '
                      'No Radxa connection or listening-history writes are performed.',
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
