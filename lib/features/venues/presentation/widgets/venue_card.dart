import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/entities/venue.dart';

/// One venue row. Shows at a glance: who it is, where it is, what state the
/// lead is in, whether anyone has visited, and when it is next due.
class VenueCard extends StatelessWidget {
  const VenueCard({super.key, required this.venue, this.onTap, this.trailing});

  final Venue venue;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final overdue = venue.isFollowUpOverdue;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      venue.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip.lead(venue.status, dense: true),
                  if (trailing != null) ...[const SizedBox(width: 4), trailing!],
                ],
              ),
              if (venue.locationLabel.isNotEmpty ||
                  venue.address.trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        venue.locationLabel.isNotEmpty
                            ? venue.locationLabel
                            : venue.address,
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
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatusChip.priority(venue.priority, dense: true),
                  StatusChip(
                    label: venue.hasBeenVisited
                        ? 'Visited ${AppDateUtils.formatShortDate(venue.lastVisitedAt)}'
                        : 'Not visited',
                    color: venue.hasBeenVisited
                        ? AppColors.secondary
                        : AppColors.textMuted,
                    icon: venue.hasBeenVisited
                        ? Icons.where_to_vote_outlined
                        : Icons.not_listed_location_outlined,
                    dense: true,
                  ),
                  if (venue.nextFollowUpAt != null)
                    StatusChip(
                      label: overdue
                          ? 'Due ${AppDateUtils.relativeLabel(venue.nextFollowUpAt)}'
                          : 'Due ${AppDateUtils.formatShortDate(venue.nextFollowUpAt)}',
                      color: overdue ? AppColors.danger : AppColors.info,
                      icon: overdue
                          ? Icons.warning_amber_rounded
                          : Icons.event_outlined,
                      dense: true,
                    ),
                  if (venue.isArchived)
                    const StatusChip(
                      label: 'Archived',
                      color: AppColors.neutral,
                      icon: Icons.archive_outlined,
                      dense: true,
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
