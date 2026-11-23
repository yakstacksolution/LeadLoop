import 'package:flutter/material.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';

/// Picks a new lead status and an optional reason.
///
/// Returns `(status, reason)` or null if dismissed. Every change is recorded
/// in the venue's status history, so the reason is worth capturing.
Future<({LeadStatus status, String reason})?> showStatusChangeSheet(
  BuildContext context, {
  required LeadStatus current,
}) {
  return showModalBottomSheet<({LeadStatus status, String reason})>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _StatusChangeSheet(current: current),
  );
}

class _StatusChangeSheet extends StatefulWidget {
  const _StatusChangeSheet({required this.current});

  final LeadStatus current;

  @override
  State<_StatusChangeSheet> createState() => _StatusChangeSheetState();
}

class _StatusChangeSheetState extends State<_StatusChangeSheet> {
  late LeadStatus _selected = widget.current;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // Bottom only: the drag handle covers the top, and the sides sit
      // against the sheet's own rounded edges.
      top: false,
      left: false,
      right: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Update lead status',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in LeadStatus.values)
                    ChoiceChip(
                      label: Text(status.label),
                      selected: _selected == status,
                      selectedColor: AppColors.forLeadStatus(
                        status,
                      ).withValues(alpha: 0.18),
                      labelStyle: TextStyle(
                        color: _selected == status
                            ? AppColors.forLeadStatus(status)
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                      onSelected: (_) => setState(() => _selected = status),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reason,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'Why is the status changing?',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _selected == widget.current
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop((status: _selected, reason: _reason.text.trim())),
                child: Text(
                  _selected == widget.current
                      ? 'Choose a different status'
                      : 'Update to ${_selected.label}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
