import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'design_widgets.dart';

Future<void> showDraftEditor(
  BuildContext context, {
  required String title,
  required Map<String, String> fields,
  Set<String> requiredFields = const {},
  Set<String> multiline = const {},
}) => showDialog<void>(
  context: context,
  builder: (_) => DraftEditor(
    title: title,
    fields: fields,
    requiredFields: requiredFields,
    multiline: multiline,
  ),
);

class DraftEditor extends StatefulWidget {
  const DraftEditor({
    super.key,
    required this.title,
    required this.fields,
    this.requiredFields = const {},
    this.multiline = const {},
  });
  final String title;
  final Map<String, String> fields;
  final Set<String> requiredFields, multiline;
  @override
  State<DraftEditor> createState() => _DraftEditorState();
}

class _DraftEditorState extends State<DraftEditor> {
  final _form = GlobalKey<FormState>();
  late final _controllers = {
    for (final entry in widget.fields.entries)
      entry.key: TextEditingController(text: entry.value),
  };
  bool _saveUnavailable = false;
  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    backgroundColor: AppTheme.surface,
    title: Text(widget.title, style: headingStyle),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Unsaved draft. Saving is not connected.',
              style: mutedStyle,
            ),
            const SizedBox(height: 16),
            for (final entry in _controllers.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextFormField(
                  key: ValueKey('draft-${entry.key}'),
                  controller: entry.value,
                  minLines: widget.multiline.contains(entry.key) ? 4 : 1,
                  maxLines: widget.multiline.contains(entry.key) ? 10 : 1,
                  decoration: InputDecoration(
                    labelText: entry.key,
                    alignLabelWithHint: true,
                  ),
                  validator: (value) =>
                      widget.requiredFields.contains(entry.key) &&
                          (value?.trim().isEmpty ?? true)
                      ? '${entry.key} is required'
                      : null,
                ),
              ),
            if (_saveUnavailable)
              const Text(
                'Saving unavailable. Your draft has not been applied.',
                key: ValueKey('draft-feedback'),
                style: TextStyle(color: AppTheme.muted),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        key: const ValueKey('draft-cancel'),
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        key: const ValueKey('draft-save'),
        onPressed: () {
          if (_form.currentState!.validate()) {
            setState(() => _saveUnavailable = true);
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}

Future<void> showUnavailableConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool enabled = false,
}) => showDialog<void>(
  context: context,
  builder: (_) => _UnavailableConfirmation(
    title: title,
    message: message,
    action: action,
    enabled: enabled,
  ),
);

class _UnavailableConfirmation extends StatefulWidget {
  const _UnavailableConfirmation({
    required this.title,
    required this.message,
    required this.action,
    required this.enabled,
  });
  final String title, message, action;
  final bool enabled;
  @override
  State<_UnavailableConfirmation> createState() =>
      _UnavailableConfirmationState();
}

class _UnavailableConfirmationState extends State<_UnavailableConfirmation> {
  bool _attempted = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.title),
    content: Text(
      _attempted
          ? '${widget.action} unavailable. Nothing was changed.'
          : widget.message,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: widget.enabled
            ? () => setState(() => _attempted = true)
            : null,
        child: Text(widget.action),
      ),
    ],
  );
}
