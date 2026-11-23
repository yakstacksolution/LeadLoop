import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/activity.dart';

/// Asks what came of an activity before closing it.
///
/// A bottom sheet rather than a dialog: the note is typed, and a sheet keeps
/// the field directly above the keyboard instead of fighting a centred box
/// for the shrinking space left over.
///
/// Returns the note, or null when dismissed. An empty string is a valid
/// answer — the note is optional and the activity still completes.
Future<String?> showCompleteActivitySheet(
  BuildContext context, {
  required Activity activity,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CompleteActivitySheet(activity: activity),
  );
}

class _CompleteActivitySheet extends StatefulWidget {
  const _CompleteActivitySheet({required this.activity});

  final Activity activity;

  @override
  State<_CompleteActivitySheet> createState() => _CompleteActivitySheetState();
}

class _CompleteActivitySheetState extends State<_CompleteActivitySheet> {
  final _note = TextEditingController();

  /// The outcomes people actually type, kept short enough to tap instead.
  static const _suggestions = [
    'Went well',
    'Will follow up',
    'Not reachable',
    'Needs a decision',
  ];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _apply(String suggestion) {
    setState(() {
      // Tapping the same pill again clears it, so a mis-tap is one tap to
      // undo rather than a text selection job.
      final isSelected = _note.text.trim() == suggestion;
      _note.text = isSelected ? '' : suggestion;
      _note.selection = TextSelection.collapsed(offset: _note.text.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;

    return SafeArea(
      // Bottom only: the drag handle covers the top, and the sides sit
      // against the sheet's own rounded edges.
      top: false,
      left: false,
      right: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          // Lifts the sheet clear of the keyboard as it opens.
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 21,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Complete activity',
                          style: TextStyle(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Record what came of it.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Which activity is being closed — the detail screen is behind
              // the sheet, and on a phone this is the only reminder.
              _ActivitySummary(activity: activity),
              const SizedBox(height: 16),

              TextField(
                controller: _note,
                autofocus: true,
                maxLines: 3,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What was the outcome?',
                  hintText: 'Optional — what was said, what happens next',
                  alignLabelWithHint: true,
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final suggestion in _suggestions)
                    _SuggestionPill(
                      label: suggestion,
                      selected: _note.text.trim() == suggestion,
                      onTap: () => _apply(suggestion),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        Navigator.of(context).pop(_note.text.trim());
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Mark complete'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivitySummary extends StatelessWidget {
  const _ActivitySummary({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            AppIcons.forActivityType(activity.type),
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${activity.venueName} · '
                  '${AppDateUtils.formatDateTime(activity.scheduledAt)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionPill extends StatelessWidget {
  const _SuggestionPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.success : AppColors.textSecondary;

    return Material(
      color: selected
          ? AppColors.success.withValues(alpha: 0.10)
          : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppColors.success.withValues(alpha: 0.45)
                  : AppColors.outline,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
