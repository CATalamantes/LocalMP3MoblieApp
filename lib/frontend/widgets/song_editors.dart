import 'package:flutter/material.dart';

import '../../backend/controllers/library_controller.dart';
import '../../backend/models/music_models.dart';
import '../../backend/services/artwork/artwork_service.dart';
import 'application_binding.dart';
import 'design_widgets.dart';

Future<void> showSongEditor(
  BuildContext context,
  FrontendActions actions,
  Song song,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => SongInformationEditor(actions: actions, song: song),
);

class SongInformationEditor extends StatefulWidget {
  const SongInformationEditor({
    super.key,
    required this.actions,
    required this.song,
  });
  final FrontendActions actions;
  final Song song;
  @override
  State<SongInformationEditor> createState() => _SongInformationEditorState();
}

class _SongInformationEditorState extends State<SongInformationEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.song.title);
  late final _artist = TextEditingController(text: widget.song.artistName);
  ArtworkDraft? _replacement;
  bool _clear = false, _pending = false;
  String? _error;
  Future<void> _pick() async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final draft = await widget.actions.dependencies.library.pickArtwork();
      if (mounted && draft != null) {
        setState(() {
          _replacement = draft;
          _clear = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = actionError(error));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _save() async {
    if (_pending || !_form.currentState!.validate()) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final result = await widget.actions.dependencies.library
          .saveSongInformation(
            widget.song.songId,
            SongMetadataUpdate(
              title: _title.text.trim() == widget.song.title
                  ? null
                  : _title.text,
              artistName: _artist.text == widget.song.artistName
                  ? null
                  : _artist.text,
              replacementArtwork: _replacement,
              clearArtwork: _clear,
            ),
          );
      final warnings = [...result.warnings];
      try {
        await widget.actions.refreshSong(result.song.songId);
      } catch (_) {
        warnings.add(
          'Song saved. A view could not refresh; reopen it to reload saved data.',
        );
      }
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(['Song information saved.', ...warnings].join(' ')),
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = actionError(error));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_pending,
    child: AlertDialog(
      scrollable: true,
      title: const Text('Edit Song Information'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ArtworkFrame(
                  size: 120,
                  reference: _clear || _replacement != null
                      ? null
                      : widget.song.artworkPath,
                  bytes: _replacement?.bytes,
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _pending ? null : _pick,
                    child: const Text('Choose artwork'),
                  ),
                  TextButton(
                    onPressed: _pending
                        ? null
                        : () => setState(() {
                            _replacement = null;
                            _clear = true;
                          }),
                    child: const Text('Clear artwork'),
                  ),
                ],
              ),
              TextFormField(
                key: const ValueKey('song-title'),
                controller: _title,
                enabled: !_pending,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('song-artist'),
                controller: _artist,
                enabled: !_pending,
                decoration: const InputDecoration(labelText: 'Artist'),
              ),
              const SizedBox(height: 16),
              Text(
                '${widget.song.audioFormat} · ${playbackTime(Duration(milliseconds: widget.song.durationMs))}',
                style: mutedStyle,
              ),
              const Text(
                'PNG or JPEG, up to 5 MiB and 4096 × 4096 pixels. Changes are saved only after Save.',
                style: mutedStyle,
              ),
              if (_pending) const Text('Please wait…'),
              if (_error != null)
                Text(_error!, key: const ValueKey('song-edit-error')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('song-edit-cancel'),
          onPressed: _pending ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('song-edit-save'),
          onPressed: _pending ? null : _save,
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
