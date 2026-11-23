import 'package:flutter/material.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';

/// A compact, colour-coded label.
///
/// The background is a light tint of [color] and the text is [color] itself,
/// which keeps contrast comfortably readable while still reading as a badge.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
  });

  StatusChip.lead(LeadStatus status, {super.key, this.dense = false})
      : label = status.label,
        color = AppColors.forLeadStatus(status),
        icon = null;

  StatusChip.activity(ActivityStatus status, {super.key, this.dense = false})
      : label = status.label,
        color = AppColors.forActivityStatus(status),
        icon = null;

  StatusChip.visit(VisitStatus status, {super.key, this.dense = false})
      : label = status.label,
        color = AppColors.forVisitStatus(status),
        icon = null;

  StatusChip.priority(VenuePriority priority, {super.key, this.dense = false})
      : label = '${priority.label} priority',
        color = AppColors.forPriority(priority),
        icon = Icons.flag_outlined;

  StatusChip.project(ProjectStatus status, {super.key, this.dense = false})
      : label = status.label,
        color = AppColors.forProjectStatus(status),
        icon = null;

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: dense ? 11 : 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
