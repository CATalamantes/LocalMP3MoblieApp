import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'design_widgets.dart';
import 'application_binding.dart';

Future<void> showDraftEditor(
  BuildContext context, {
  required String title,
  required Map<String, String> fields,
  Set<String> requiredFields = const {},
  Set<String> multiline = const {},
  Future<void> Function(Map<String, String>)? onSave,
}) => showDialog<void>(
  context: context,
  builder: (_) => DraftEditor(
    title: title,
    fields: fields,
    requiredFields: requiredFields,
    multiline: multiline,
    onSave: onSave,
  ),
);

class DraftEditor extends StatefulWidget {
  const DraftEditor({
    super.key,
    required this.title,
    required this.fields,
    this.requiredFields = const {},
    this.multiline = const {},
    this.onSave,
  });
  final String title;
  final Map<String, String> fields;
  final Set<String> requiredFields, multiline;
  final Future<void> Function(Map<String, String>)? onSave;
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
  bool _pending = false;
  String? _error;
  Future<void> _save() async {
    if (_pending || !_form.currentState!.validate()) return;
    if (widget.onSave == null) {
      setState(() => _saveUnavailable = true);
      return;
    }
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await widget.onSave!({
        for (final field in _controllers.entries) field.key: field.value.text,
      });
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = actionError(error));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_pending,
    child: AlertDialog(
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
              Text(
                widget.onSave == null
                    ? 'Unsaved draft. Saving is not connected.'
                    : 'Changes are saved only after you press Save.',
                style: mutedStyle,
              ),
              const SizedBox(height: 16),
              for (final entry in _controllers.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    key: ValueKey('draft-${entry.key}'),
                    controller: entry.value,
                    enabled: !_pending,
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
              if (_pending) const Text('Saving…'),
              if (_error != null)
                Text(
                  _error!,
                  key: const ValueKey('draft-error'),
                  style: mutedStyle,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('draft-cancel'),
          onPressed: _pending ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('draft-save'),
          onPressed: _pending ? null : _save,
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<void> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  required Future<String> Function() onConfirm,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _ActionConfirmation(
    title: title,
    message: message,
    action: action,
    onConfirm: onConfirm,
  ),
);

class _ActionConfirmation extends StatefulWidget {
  const _ActionConfirmation({
    required this.title,
    required this.message,
    required this.action,
    required this.onConfirm,
  });
  final String title, message, action;
  final Future<String> Function() onConfirm;
  @override
  State<_ActionConfirmation> createState() => _ActionConfirmationState();
}

class _ActionConfirmationState extends State<_ActionConfirmation> {
  bool pending = false;
  String? result, error;
  Future<void> submit() async {
    if (pending || result != null) return;
    setState(() {
      pending = true;
      error = null;
    });
    try {
      final value = await widget.onConfirm();
      if (mounted) setState(() => result = value);
    } catch (failure) {
      if (mounted) setState(() => error = actionError(failure));
    } finally {
      if (mounted) setState(() => pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !pending,
    child: AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Text(result ?? error ?? (pending ? 'Working…' : widget.message)),
      actions: [
        TextButton(
          onPressed: pending ? null : () => Navigator.pop(context),
          child: Text(result == null ? 'Cancel' : 'Close'),
        ),
        if (result == null)
          TextButton(
            onPressed: pending ? null : submit,
            child: Text(widget.action),
          ),
      ],
    ),
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
