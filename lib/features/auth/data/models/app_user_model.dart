import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/utils/firestore_mapper.dart';
import '../../domain/entities/app_user.dart';

/// Firestore serialisation for `/users/{uid}`.
extension AppUserMapper on AppUser {
  /// Fields a client is allowed to write.
  ///
  /// `role`, `status` and `assignedProjectIds` are intentionally absent: they
  /// are owned by the Cloud Functions and rejected by the security rules on a
  /// self-update. Admin-side edits go through the dedicated callables.
  Map<String, dynamic> toProfileUpdate() => {
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'employeeCode': employeeCode.trim(),
        'updatedAt': serverTime,
      };
}

abstract final class AppUserModel {
  static AppUser fromMap(String id, Map<String, dynamic> data) {
    return AppUser(
      id: id,
      fullName: Read.string(data, 'fullName'),
      email: Read.string(data, 'email'),
      phone: Read.string(data, 'phone'),
      employeeCode: Read.string(data, 'employeeCode'),
      role: UserRole.fromValue(Read.stringOrNull(data, 'role')),
      status: UserStatus.fromValue(Read.stringOrNull(data, 'status')),
      assignedProjectIds: Read.stringList(data, 'assignedProjectIds'),
      createdAt: Read.dateTime(data, 'createdAt'),
      updatedAt: Read.dateTime(data, 'updatedAt'),
      createdBy: Read.stringOrNull(data, 'createdBy'),
    );
  }

  static AppUser fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      fromMap(doc.id, doc.data() ?? const {});
}
