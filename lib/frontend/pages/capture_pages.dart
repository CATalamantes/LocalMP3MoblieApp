import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../routes/app_screen.dart';
import '../routes/frontend_navigation.dart';
import '../theme/app_theme.dart';
import '../widgets/design_widgets.dart';
import '../widgets/presentation.dart';
import '../widgets/unknown_meter.dart';

class AddMusicPage extends StatefulWidget {
  const AddMusicPage({super.key, required this.data});
  final ScreenPresentation data;
  @override
  State<AddMusicPage> createState() => _AddMusicPageState();
}

class _AddMusicPageState extends State<AddMusicPage> {
  final _url = TextEditingController();
  String? _pasteError;
  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    try {
      final value = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      setState(() {
        _url.text = value?.text ?? '';
        _pasteError = value == null ? 'Clipboard is empty.' : null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _pasteError = 'Clipboard unavailable. Enter a URL manually.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    screen: AppScreen.addMusic,
    children: [
      SurfaceCard(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final choices = <Widget>[
              Semantics(
                selected: true,
                child: ActionPill(
                  'Download from URL',
                  primary: true,
                  onPressed: () => FocusScope.of(context).unfocus(),
                ),
              ),
              ActionPill(
                'Record Audio',
                icon: Icons.mic_none,
                onPressed: () => openScreen(context, AppScreen.record),
              ),
            ];
            if (constraints.maxWidth < 280 ||
                MediaQuery.textScalerOf(context).scale(14) > 20) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [choices[0], const SizedBox(height: 12), choices[1]],
              );
            }
            return Row(
              children: [
                Expanded(child: choices[0]),
                const SizedBox(width: 12),
                Expanded(child: choices[1]),
              ],
            );
          },
        ),
      ),
      SurfaceCard(
        emphasis: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Paste Audio URL', style: headingStyle),
            const SizedBox(height: 12),
            const Wrap(children: [StatusPill('Metadata unavailable')]),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('audio-url'),
              controller: _url,
              keyboardType: TextInputType.url,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(
                labelText: 'Audio URL',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: IconButton(
                  tooltip: 'Paste URL',
                  onPressed: _paste,
                  icon: const Icon(Icons.content_paste),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                final uri = Uri.tryParse(value);
                return uri == null ||
                        !{'http', 'https'}.contains(uri.scheme) ||
                        uri.host.isEmpty
                    ? 'Enter an HTTP or HTTPS URL'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            if (_pasteError != null) Text(_pasteError!, style: mutedStyle),
            const SizedBox(height: 16),
            const ActionPill(
              'Download Song',
              primary: true,
              icon: Icons.download_outlined,
            ),
            const SizedBox(height: 16),
            const Text(
              'Downloads and metadata lookup require supported device integration. No URL is submitted.',
              style: mutedStyle,
            ),
          ],
        ),
      ),
      const SurfaceCard(
        child: SettingsRow(
          title: 'Import Local Audio File',
          subtitle: 'MP3, FLAC, WAV · Importing unavailable',
          icon: Icons.folder_open,
          trailing: Icon(Icons.lock_outline, color: AppTheme.muted),
        ),
      ),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Digitize Physical Media', style: titleStyle),
            const SizedBox(height: 12),
            const Text(
              'Record from a turntable or CD player through the MP3 player’s external audio hardware.',
              style: mutedStyle,
            ),
            const SizedBox(height: 12),
            const ScreenLink(
              screen: AppScreen.record,
              label: 'Switch to Record Audio',
              subtitle: 'Vinyl & CD Digitization',
              icon: Icons.album_outlined,
            ),
          ],
        ),
      ),
      const SectionTitle('Recent Downloads'),
      const SurfaceCard(
        child: Text(
          'No downloads available. Download history is not connected.',
          style: mutedStyle,
        ),
      ),
      PresentationNotice(
        data: widget.data,
        empty: 'No music imports',
        unconnected: 'Importing and downloading are unavailable.',
      ),
    ],
  );
}

class RecordPage extends StatelessWidget {
  const RecordPage({super.key, required this.data});
  final ScreenPresentation data;
  @override
  Widget build(BuildContext context) => PageBody(
    screen: AppScreen.record,
    children: [
      const Text('Vinyl & CD Digitization', style: mutedStyle),
      const SizedBox(height: 16),
      const SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsRow(
              title: 'Line-In / USB Audio Interface',
              subtitle: 'No input device connected',
              icon: Icons.cable,
            ),
            StatusPill('Recording unavailable'),
            SizedBox(height: 12),
            Text(
              'External capture is handled by the physical player. No recording is active.',
              style: mutedStyle,
            ),
          ],
        ),
      ),
      const SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ELAPSED CAPTURE TIME',
              style: TextStyle(fontSize: 11, color: AppTheme.muted),
            ),
            SizedBox(height: 12),
            Text(
              '—:—:—',
              style: TextStyle(
                fontSize: 34,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 16),
            Text('STEREO INPUT · LEVEL UNAVAILABLE', style: mutedStyle),
            SizedBox(height: 22),
            Icon(Icons.graphic_eq, size: 58, color: AppTheme.outline),
            SizedBox(height: 20),
            UnknownMeter(label: 'Input levels unavailable'),
            SizedBox(height: 18),
            ActionPill(
              'Start Recording',
              icon: Icons.fiber_manual_record,
              primary: true,
            ),
            SizedBox(height: 10),
            ActionPill('Stop & Save Recording', icon: Icons.stop),
            SizedBox(height: 10),
            ActionPill('Mark Track Split', icon: Icons.content_cut),
          ],
        ),
      ),
      const SectionTitle('Captured Track Splits'),
      SurfaceCard(
        child: data.recording == null
            ? const Text(
                'No captured tracks. No recording files have been created.',
                style: mutedStyle,
              )
            : Column(
                children: [
                  const Text(
                    'Design sample · Split layout only',
                    style: mutedStyle,
                  ),
                  for (var i = 0; i < data.songs.length; i++)
                    SettingsRow(
                      title: '${i + 1}. ${data.songs[i].title}',
                      subtitle: 'No captured file',
                      trailing: const Icon(
                        Icons.content_cut,
                        color: AppTheme.muted,
                      ),
                    ),
                ],
              ),
      ),
      const ScreenLink(
        screen: AppScreen.saveRecording,
        label: 'Save Recording / Track Information',
        subtitle: 'Open the unsaved metadata form',
        icon: Icons.edit_note,
      ),
      PresentationNotice(
        data: data,
        empty: 'No recordings available',
        unconnected: 'Recording requires supported external hardware.',
      ),
    ],
  );
}

class SaveRecordingPage extends StatefulWidget {
  const SaveRecordingPage({super.key, required this.data});
  final ScreenPresentation data;
  @override
  State<SaveRecordingPage> createState() => _SaveRecordingPageState();
}

class _SaveRecordingPageState extends State<SaveRecordingPage> {
  final _form = GlobalKey<FormState>();
  late final _fields = {
    for (final name in [
      'Title',
      'Artist',
      'Album title',
      'Release year',
      'Genre',
    ])
      name: TextEditingController(),
  };
  bool _unavailable = false;
  Widget _field(String name) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey('recording-$name'),
      controller: _fields[name],
      decoration: InputDecoration(labelText: name),
      validator: (value) => name == 'Title' && (value?.trim().isEmpty ?? true)
          ? 'Title is required'
          : null,
    ),
  );

  Widget _metadata() => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(14) > 20) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: ArtworkFrame(size: 90),
            ),
            const SizedBox(height: 12),
            const ActionPill(
              'Replace Cover',
              icon: Icons.add_photo_alternate_outlined,
            ),
            const SizedBox(height: 16),
            for (final name in _fields.keys) _field(name),
          ],
        );
      }
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 96,
                child: Column(
                  children: [
                    ArtworkFrame(size: 90),
                    TextButton(onPressed: null, child: Text('Replace Cover')),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(children: [_field('Title'), _field('Artist')]),
              ),
            ],
          ),
          _field('Album title'),
          Row(
            children: [
              Expanded(child: _field('Release year')),
              const SizedBox(width: 12),
              Expanded(child: _field('Genre')),
            ],
          ),
        ],
      );
    },
  );
  @override
  void dispose() {
    for (final value in _fields.values) {
      value.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageBody(
    screen: AppScreen.saveRecording,
    children: [
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StatusPill('Recording session'),
            const SizedBox(height: 14),
            Text(
              widget.data.recording == null
                  ? 'No recording captured'
                  : 'Design sample · recording metadata',
              style: titleStyle,
            ),
            const SizedBox(height: 8),
            const Text(
              'Metadata draft only. No audio file will be created.',
              style: mutedStyle,
            ),
          ],
        ),
      ),
      SurfaceCard(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Album & Metadata', style: headingStyle),
              const SizedBox(height: 16),
              _metadata(),
              const ActionPill(
                'Fetch Cover & ID3',
                icon: Icons.cloud_download_outlined,
              ),
            ],
          ),
        ),
      ),
      const SectionTitle('Divided Tracks'),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.data.recording == null)
              const Text('No captured track splits', style: mutedStyle)
            else ...[
              const Text(
                'Design sample · Split layout only',
                style: mutedStyle,
              ),
              for (final song in widget.data.songs)
                SettingsRow(
                  title: song.title,
                  subtitle: '${song.durationMs} ms · ${song.audioFormat}',
                  trailing: const IconButton(
                    onPressed: null,
                    tooltip: 'Split editing unavailable',
                    icon: Icon(Icons.content_cut),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            const ActionPill('Add Track Split', icon: Icons.add),
          ],
        ),
      ),
      const SectionTitle('Destination & Sync'),
      const SurfaceCard(
        child: Column(
          children: [
            SettingsRow(
              title: 'Save to MP3 Capsule Library',
              subtitle: 'Destination unavailable',
              icon: Icons.storage,
              trailing: Switch(value: false, onChanged: null),
            ),
            SettingsRow(
              title: 'Export Copy to Phone Storage',
              subtitle: 'Export unavailable',
              icon: Icons.phone_android,
              trailing: Switch(value: false, onChanged: null),
            ),
          ],
        ),
      ),
      ActionPill(
        'Save & Add to Library',
        primary: true,
        icon: Icons.library_add_check_outlined,
        onPressed: widget.data.recording == null
            ? null
            : () {
                if (_form.currentState!.validate()) {
                  setState(() => _unavailable = true);
                }
              },
      ),
      if (_unavailable)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Text(
            'Saving unavailable. No recording or library entry was created.',
            style: mutedStyle,
          ),
        ),
      TextButton(
        onPressed: () {
          for (final value in _fields.values) {
            value.clear();
          }
          setState(() => _unavailable = false);
          FocusScope.of(context).unfocus();
        },
        child: const Text('Cancel draft'),
      ),
      PresentationNotice(
        data: widget.data,
        empty: 'No recording to save',
        unconnected: 'Recording storage is not connected.',
      ),
    ],
  );
}
