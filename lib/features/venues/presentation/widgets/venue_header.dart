import 'package:flutter/material.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/entities/venue.dart';

/// The venue's identity and current state, at the top of the detail screen.
///
/// Answers the four questions a field rep opens this screen with: where is it,
/// what state is the lead in, is anything overdue, and has anyone been there.
class VenueHeader extends StatelessWidget {
  const VenueHeader({super.key, required this.venue, this.onStatusTap});

  final Venue venue;
  final VoidCallback? onStatusTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = AppColors.forLeadStatus(venue.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.stadium_outlined, color: statusColor, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    if (venue.locationLabel.isNotEmpty ||
                        venue.address.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 13, color: AppColors.textMuted),
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Current status, tappable — changing it is the most common action.
          _StatusBar(venue: venue, onTap: onStatusTap),

          const SizedBox(height: 12),
          _PipelineTrack(status: venue.status),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          Row(
            children: [
              _Metric(
                icon: Icons.where_to_vote_outlined,
                label: 'Visits',
                value: venue.hasBeenVisited ? '${venue.visitCount}' : 'None',
                color: venue.hasBeenVisited
                    ? AppColors.secondary
                    : AppColors.textMuted,
              ),
              _Metric(
                icon: Icons.event_repeat_outlined,
                label: 'Next follow-up',
                value: venue.nextFollowUpAt == null
                    ? 'Not set'
                    : AppDateUtils.formatShortDate(venue.nextFollowUpAt),
                color: venue.isFollowUpOverdue
                    ? AppColors.danger
                    : AppColors.info,
              ),
              _Metric(
                icon: Icons.bolt_outlined,
                label: 'Last activity',
                value: venue.lastActivityAt == null
                    ? '—'
                    : AppDateUtils.formatShortDate(venue.lastActivityAt),
                color: AppColors.textSecondary,
              ),
            ],
          ),

          if (venue.isFollowUpOverdue) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 17, color: AppColors.danger),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Follow-up ${AppDateUtils.relativeLabel(venue.nextFollowUpAt)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.venue, this.onTap});

  final Venue venue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forLeadStatus(venue.status);

    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lead status',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                    ),
                    Text(
                      venue.status.label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip.priority(venue.priority, dense: true),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.edit_outlined, size: 16, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact read of how far along the pipeline this lead is.
///
/// Only the seven statuses that form the forward path are shown as steps. The
/// off-path states (Not interested, Unresponsive, On hold, Follow-up required)
/// have no position on a track, so the track is replaced by a plain note —
/// inventing a position for them would be misleading.
class _PipelineTrack extends StatelessWidget {
  const _PipelineTrack({required this.status});

  final LeadStatus status;

  static const _track = [
    LeadStatus.newLead,
    LeadStatus.contacted,
    LeadStatus.interested,
    LeadStatus.meetingScheduled,
    LeadStatus.visited,
    LeadStatus.negotiation,
    LeadStatus.converted,
  ];

  @override
  Widget build(BuildContext context) {
    final index = _track.indexOf(status);

    if (index < 0) {
      return Row(
        children: [
          Icon(Icons.info_outline, size: 13, color: AppColors.forLeadStatus(status)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${status.label} — off the main pipeline',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ),
        ],
      );
    }

    final color = AppColors.forLeadStatus(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < _track.length; i++) ...[
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= index ? color : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i != _track.length - 1) const SizedBox(width: 3),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Text(
          'Step ${index + 1} of ${_track.length}',
          style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
