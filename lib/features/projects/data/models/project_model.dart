import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/utils/firestore_mapper.dart';
import '../../domain/entities/project.dart';

abstract final class ProjectModel {
  static Project fromMap(String id, Map<String, dynamic> data) {
    return Project(
      id: id,
      name: Read.string(data, 'name'),
      description: Read.string(data, 'description'),
      area: Read.string(data, 'area'),
      startDate: Read.dateTime(data, 'startDate'),
      endDate: Read.dateTime(data, 'endDate'),
      status: ProjectStatus.fromValue(Read.stringOrNull(data, 'status')),
      priority: VenuePriority.fromValue(Read.stringOrNull(data, 'priority')),
      assignedEmployeeIds: Read.stringList(data, 'assignedEmployeeIds'),
      createdBy: Read.stringOrNull(data, 'createdBy'),
      createdAt: Read.dateTime(data, 'createdAt'),
      updatedAt: Read.dateTime(data, 'updatedAt'),
    );
  }

  static Project fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      fromMap(doc.id, doc.data() ?? const {});

  static Map<String, dynamic> toCreateMap(Project project, String createdBy) => {
        'name': project.name.trim(),
        'description': project.description.trim(),
        'area': project.area.trim(),
        'startDate': toTimestamp(project.startDate),
        'endDate': toTimestamp(project.endDate),
        'status': project.status.value,
        'priority': project.priority.value,
        'assignedEmployeeIds': project.assignedEmployeeIds,
        'createdBy': createdBy,
        'createdAt': serverTime,
        'updatedAt': serverTime,
      };

  static Map<String, dynamic> toUpdateMap(Project project) => {
        'name': project.name.trim(),
        'description': project.description.trim(),
        'area': project.area.trim(),
        'startDate': toTimestamp(project.startDate),
        'endDate': toTimestamp(project.endDate),
        'status': project.status.value,
        'priority': project.priority.value,
        'updatedAt': serverTime,
      };
}
