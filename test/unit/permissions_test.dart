import 'package:flutter_test/flutter_test.dart';
import 'package:futsal_lead/core/constants/enums.dart';
import 'package:futsal_lead/features/auth/domain/entities/app_user.dart';

AppUser _user({
  UserRole role = UserRole.employee,
  UserStatus status = UserStatus.active,
  List<String> projects = const [],
  String name = 'Dilli Bhandari',
}) {
  return AppUser(
    id: 'uid-1',
    fullName: name,
    email: 'test@hamrofutsal.com',
    role: role,
    status: status,
    assignedProjectIds: projects,
  );
}

void main() {
  group('project access', () {
    test('an employee reaches only their assigned projects', () {
      final user = _user(projects: ['p1', 'p2']);

      expect(user.canAccessProject('p1'), isTrue);
      expect(user.canAccessProject('p3'), isFalse);
    });

    test('an admin reaches every project without being assigned', () {
      final admin = _user(role: UserRole.admin);

      expect(admin.assignedProjectIds, isEmpty);
      expect(admin.canAccessProject('anything'), isTrue);
    });

    test('an employee with no assignments reaches nothing', () {
      expect(_user().canAccessProject('p1'), isFalse);
    });
  });

  group('status', () {
    test('a disabled account is not active', () {
      expect(_user(status: UserStatus.disabled).isActive, isFalse);
    });
  });

  group('initials', () {
    test('uses first and last name', () {
      expect(_user(name: 'Dilli Bhandari').initials, 'DB');
    });

    test('handles a single name', () {
      expect(_user(name: 'Dilli').initials, 'D');
    });

    test('falls back rather than crashing on an empty name', () {
      expect(_user(name: '   ').initials, '?');
    });
  });

  group('enum parsing', () {
    test('unknown values fall back to a safe default', () {
      expect(UserRole.fromValue('superuser'), UserRole.employee);
      expect(LeadStatus.fromValue('nonsense'), LeadStatus.newLead);
      expect(ActivityStatus.fromValue(null), ActivityStatus.scheduled);
      expect(VisitStatus.fromValue('???'), VisitStatus.planned);
    });

    test('round-trips through the stored value', () {
      for (final status in LeadStatus.values) {
        expect(LeadStatus.fromValue(status.value), status);
      }
    });

    test('closed statuses are converted and not interested only', () {
      final closed = LeadStatus.values.where((s) => s.isClosed).toSet();
      expect(closed, {LeadStatus.converted, LeadStatus.notInterested});
    });

    test('scheduled and rescheduled are the open activity statuses', () {
      final open = ActivityStatus.values.where((s) => s.isOpen).toSet();
      expect(open, {ActivityStatus.scheduled, ActivityStatus.rescheduled});
    });
  });
}
