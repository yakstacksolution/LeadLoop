import 'package:flutter/material.dart';

import '../errors/failures.dart';
import '../theme/app_colors.dart';

extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;

  /// Tablet and desktop layouts switch on this single breakpoint, so the
  /// adaptive rules stay consistent across every screen.
  bool get isWide => MediaQuery.sizeOf(this).width >= 900;
  bool get isMedium => MediaQuery.sizeOf(this).width >= 640;

  void showSnack(String message, {Color? background, IconData? icon}) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: background,
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 10),
              ],
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  void showSuccess(String message) => showSnack(
    message,
    background: AppColors.success,
    icon: Icons.check_circle_outline,
  );

  void showError(Object error) {
    final message = error is Failure ? error.message : error.toString();
    showSnack(message, background: AppColors.danger, icon: Icons.error_outline);
  }
}

/// The icon badge every app dialog opens with.
///
/// A tinted circle rather than a bare glyph: at a glance the colour says
/// whether this is a question, a warning or a confirmation, before any of the
/// text is read.
class _DialogIcon extends StatelessWidget {
  const _DialogIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 23, color: color),
    );
  }
}

/// Asks the user to confirm an action that is awkward to undo.
///
/// Returns true only on an explicit yes; dismissing the dialog counts as no.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
  IconData? icon,
}) async {
  final accent = isDestructive ? AppColors.danger : AppColors.primary;

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: _DialogIcon(
        icon:
            icon ??
            (isDestructive
                ? Icons.warning_amber_rounded
                : Icons.help_outline_rounded),
        color: accent,
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13.5,
          height: 1.45,
          color: AppColors.textSecondary,
        ),
      ),
      // Stacked full-width buttons: the confirm button is the one being
      // aimed at, and a 48dp target beats a text link in the corner.
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: isDestructive
                    ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                    : null,
                child: Text(confirmLabel),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                child: Text(cancelLabel),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  return result ?? false;
}

/// Prompts for a single line or paragraph of text. Returns null if cancelled.
Future<String?> promptForText(
  BuildContext context, {
  required String title,
  String? label,
  String? hint,
  String initialValue = '',
  String confirmLabel = 'Save',
  int maxLines = 3,
  int? maxLength = 500,
  IconData icon = Icons.edit_outlined,
  bool required = true,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: title,
      label: label,
      hint: hint,
      initialValue: initialValue,
      confirmLabel: confirmLabel,
      maxLines: maxLines,
      maxLength: maxLength,
      icon: icon,
      required: required,
    ),
  );
}

/// Owns its controller, so it outlives the dialog's exit animation. Disposing
/// it when `showDialog` returns would pull it from a field still on screen.
class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.confirmLabel,
    required this.maxLines,
    required this.maxLength,
    required this.icon,
    required this.required,
  });

  final String title;
  final String? label;
  final String? hint;
  final String initialValue;
  final String confirmLabel;
  final int maxLines;
  final int? maxLength;
  final IconData icon;
  final bool required;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: _DialogIcon(icon: widget.icon, color: AppColors.primary),
      title: Text(widget.title, textAlign: TextAlign.center),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: widget.label ?? 'Text',
            hintText: widget.hint,
            alignLabelWithHint: widget.maxLines > 1,
            counterText: '',
          ),
          validator: widget.required
              ? (value) => (value?.trim().isEmpty ?? true)
                    ? 'Please enter something.'
                    : null
              : null,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    Navigator.of(context).pop(_controller.text.trim());
                  }
                },
                child: Text(widget.confirmLabel),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
