import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/entities/visit.dart';

/// One visit in a history list.
///
/// The evidence chip is the point of this tile: it says plainly whether the
/// visit was merely marked by the employee or backed by a location fix, so an
/// admin is never misled into treating the two as equivalent.
class VisitTile extends StatelessWidget {
  const VisitTile({super.key, required this.visit, this.onTap, this.showVenue = false});

  final Visit visit;
  final VoidCallback? onTap;
  final bool showVenue;

  @override
  Widget build(BuildContext context) {
    final duration = visit.durationLabel;

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
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.forVisitStatus(visit.status)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.where_to_vote_outlined,
                      size: 17,
                      color: AppColors.forVisitStatus(visit.status),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          showVenue && visit.venueName.isNotEmpty
                              ? visit.venueName
                              : AppDateUtils.formatDateTime(visit.startAt),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (showVenue && visit.venueName.isNotEmpty)
                          Text(
                            AppDateUtils.formatDateTime(visit.startAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  StatusChip.visit(visit.status, dense: true),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatusChip(
                    label: visit.evidenceLabel,
                    color: visit.isLocationSupported
                        ? AppColors.secondary
                        : AppColors.textMuted,
                    icon: visit.isLocationSupported
                        ? Icons.my_location
                        : Icons.person_outline,
                    dense: true,
                  ),
                  if (duration != null)
                    StatusChip(
                      label: duration,
                      color: AppColors.info,
                      icon: Icons.timer_outlined,
                      dense: true,
                    ),
                  if (visit.hasLocation && visit.locationAccuracy != null)
                    StatusChip(
                      label: '±${visit.locationAccuracy!.round()} m',
                      color: AppColors.textMuted,
                      dense: true,
                    ),
                ],
              ),
              if (visit.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  visit.notes,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
