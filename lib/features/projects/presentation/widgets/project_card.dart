import 'package:flutter/material.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/entities/project.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.project, this.onTap});

  final Project project;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
                  // Tinted by status, so an archived project reads as closed
                  // before its chip is examined.
                  Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: AppColors.forProjectStatus(project.status)
                          .withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      project.status == ProjectStatus.archived
                          ? Icons.inventory_2_outlined
                          : Icons.folder_outlined,
                      size: 19,
                      color: AppColors.forProjectStatus(project.status),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      project.name,
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
                  StatusChip.project(project.status, dense: true),
                ],
              ),
              if (project.description.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  project.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatusChip.priority(project.priority, dense: true),
                  if (project.area.trim().isNotEmpty)
                    StatusChip(
                      label: project.area,
                      color: AppColors.info,
                      icon: Icons.place_outlined,
                      dense: true,
                    ),
                  StatusChip(
                    label: project.assignedEmployeeIds.isEmpty
                        ? 'No one assigned'
                        : '${project.assignedEmployeeIds.length} assigned',
                    color: project.assignedEmployeeIds.isEmpty
                        ? AppColors.textMuted
                        : AppColors.secondary,
                    icon: Icons.groups_outlined,
                    dense: true,
                  ),
                  if (project.startDate != null)
                    StatusChip(
                      label: project.endDate == null
                          ? 'From ${AppDateUtils.formatShortDate(project.startDate)}'
                          : '${AppDateUtils.formatShortDate(project.startDate)} – '
                              '${AppDateUtils.formatShortDate(project.endDate)}',
                      color: AppColors.textMuted,
                      icon: Icons.calendar_today_outlined,
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
