import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/entities/activity.dart';

/// One row in any activity or follow-up list.
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    this.onTap,
    this.showVenue = true,
    this.trailing,
  });

  final Activity activity;
  final VoidCallback? onTap;
  final bool showVenue;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final overdue = activity.isOverdue;
    final accent = overdue ? AppColors.danger : AppColors.forActivityStatus(activity.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(AppIcons.forActivityType(activity.type), size: 19, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title.trim().isEmpty
                          ? activity.type.label
                          : activity.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    if (showVenue && activity.venueName.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.stadium_outlined,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              activity.venueName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusChip(
                          label: AppDateUtils.formatDateTime(activity.scheduledAt),
                          color: accent,
                          icon: Icons.schedule,
                          dense: true,
                        ),
                        if (overdue)
                          StatusChip(
                            label: AppDateUtils.relativeLabel(activity.scheduledAt),
                            color: AppColors.danger,
                            icon: Icons.warning_amber_rounded,
                            dense: true,
                          )
                        else if (activity.status.isOpen)
                          StatusChip(
                            label: AppDateUtils.relativeLabel(activity.scheduledAt),
                            color: AppColors.textMuted,
                            dense: true,
                          ),
                        if (!activity.status.isOpen)
                          StatusChip.activity(activity.status, dense: true),
                      ],
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
