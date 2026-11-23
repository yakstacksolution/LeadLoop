import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// A person who can sign in: admin or employee.
///
/// `assignedProjectIds` is the single source of truth for an employee's scope
/// and is enforced identically in the Firestore security rules.
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
    this.phone = '',
    this.employeeCode = '',
    this.assignedProjectIds = const [],
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String employeeCode;
  final UserRole role;
  final UserStatus status;
  final List<String> assignedProjectIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  bool get isAdmin => role.isAdmin;
  bool get isActive => status.isActive;

  /// Admins are implicitly scoped to everything; employees only to their list.
  bool canAccessProject(String projectId) =>
      isAdmin || assignedProjectIds.contains(projectId);

  /// First letters of the name, for avatars.
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  AppUser copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? employeeCode,
    UserRole? role,
    UserStatus? status,
    List<String>? assignedProjectIds,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      employeeCode: employeeCode ?? this.employeeCode,
      role: role ?? this.role,
      status: status ?? this.status,
      assignedProjectIds: assignedProjectIds ?? this.assignedProjectIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fullName,
        email,
        phone,
        employeeCode,
        role,
        status,
        assignedProjectIds,
        createdAt,
        updatedAt,
        createdBy,
      ];
}
