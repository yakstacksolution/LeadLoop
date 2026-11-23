/// Every route path in the app, in one place.
///
/// Employees and admins share the venue, activity and visit detail screens —
/// the security rules, not separate routes, are what keep the data correct.
abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const bootstrap = '/setup';
  static const accountDisabled = '/account-disabled';

  // Admin
  static const adminDashboard = '/admin';
  static const employees = '/admin/employees';
  static const createEmployee = '/admin/employees/new';
  static const employeeDetail = '/admin/employees/:id';
  static const projects = '/admin/projects';
  static const createProject = '/admin/projects/new';
  static const projectDetail = '/admin/projects/:id';
  static const editProject = '/admin/projects/:id/edit';
  static const adminVenues = '/admin/venues';
  static const adminActivities = '/admin/activities';
  static const adminVisits = '/admin/visits';
  static const reports = '/admin/reports';

  // Employee
  static const employeeHome = '/home';
  static const myProjects = '/my-projects';
  static const myVenues = '/my-venues';
  static const followUps = '/follow-ups';

  // Shared
  static const createVenue = '/venues/new';
  static const venueDetail = '/venues/:id';
  static const editVenue = '/venues/:id/edit';
  static const venueContacts = '/venues/:id/contacts';
  static const scheduleActivity = '/venues/:id/schedule';
  static const recordVisit = '/venues/:id/visit';
  static const activityDetail = '/activities/:id';
  static const profile = '/profile';

  static String employeeDetailFor(String id) => '/admin/employees/$id';
  static String projectDetailFor(String id) => '/admin/projects/$id';
  static String editProjectFor(String id) => '/admin/projects/$id/edit';
  static String venueDetailFor(String id) => '/venues/$id';
  static String editVenueFor(String id) => '/venues/$id/edit';
  static String venueContactsFor(String id) => '/venues/$id/contacts';
  static String scheduleActivityFor(String id) => '/venues/$id/schedule';
  static String recordVisitFor(String id) => '/venues/$id/visit';
  static String activityDetailFor(String id) => '/activities/$id';
}
