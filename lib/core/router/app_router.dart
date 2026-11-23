import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/activities/presentation/pages/activity_detail_page.dart';
import '../../features/activities/presentation/pages/schedule_activity_page.dart';
import '../../features/auth/presentation/bloc/auth_cubit.dart';
import '../../features/auth/presentation/pages/account_disabled_page.dart';
import '../../features/auth/presentation/pages/bootstrap_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/startup_screen.dart';
import '../../features/dashboard/presentation/pages/admin_dashboard_page.dart';
import '../../features/dashboard/presentation/pages/employee_dashboard_page.dart';
import '../../features/employees/presentation/pages/create_employee_page.dart';
import '../../features/employees/presentation/pages/employee_detail_page.dart';
import '../../features/employees/presentation/pages/employee_list_page.dart';
import '../../features/follow_ups/presentation/pages/follow_ups_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/projects/presentation/pages/project_detail_page.dart';
import '../../features/projects/presentation/pages/project_form_page.dart';
import '../../features/projects/presentation/pages/project_list_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/venues/presentation/pages/venue_detail_page.dart';
import '../../features/venues/presentation/pages/venue_form_page.dart';
import '../../features/venues/presentation/pages/venue_list_page.dart';
import '../../features/visits/presentation/pages/record_visit_page.dart';
import '../../features/visits/presentation/pages/visit_history_page.dart';
import '../../shared/widgets/app_shell.dart';
import 'app_routes.dart';

/// Builds the router and keeps it in step with the session.
///
/// Guarding here is a convenience, not the security boundary: an employee who
/// forced their way to an admin route would still be refused by the Firestore
/// rules. The redirect simply stops people landing on screens that would only
/// show them permission errors.
GoRouter createRouter(AuthCubit authCubit) {
  final rootKey = GlobalKey<NavigatorState>();

  /// Routes reachable while signed out.
  const publicRoutes = {
    AppRoutes.login,
    AppRoutes.forgotPassword,
    AppRoutes.splash,
  };

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: AppRoutes.splash,
    // Rebuilds the redirect whenever the session changes, so disabling an
    // account boots that user out of the app straight away.
    refreshListenable: _CubitRefreshListenable(authCubit.stream),
    redirect: (context, routerState) {
      final auth = authCubit.state;
      final location = routerState.matchedLocation;

      switch (auth.status) {
        case AuthStatus.unknown:
          return location == AppRoutes.splash ? null : AppRoutes.splash;

        case AuthStatus.unauthenticated:
          return publicRoutes.contains(location) && location != AppRoutes.splash
              ? null
              : AppRoutes.login;

        case AuthStatus.needsBootstrap:
          return location == AppRoutes.bootstrap ? null : AppRoutes.bootstrap;

        case AuthStatus.disabled:
          return location == AppRoutes.accountDisabled
              ? null
              : AppRoutes.accountDisabled;

        case AuthStatus.authenticated:
          final home =
              auth.isAdmin ? AppRoutes.adminDashboard : AppRoutes.employeeHome;

          // Bounce off the signed-out screens once a session exists.
          if (publicRoutes.contains(location) ||
              location == AppRoutes.bootstrap ||
              location == AppRoutes.accountDisabled) {
            return home;
          }

          // Keep each role inside its own section.
          final isAdminArea = location.startsWith('/admin');
          if (isAdminArea && !auth.isAdmin) return AppRoutes.employeeHome;
          if (!auth.isAdmin) return null;

          const employeeOnly = {
            AppRoutes.employeeHome,
            AppRoutes.myProjects,
            AppRoutes.myVenues,
            AppRoutes.followUps,
          };
          if (employeeOnly.contains(location)) return AppRoutes.adminDashboard;

          return null;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) => const StartupScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.bootstrap,
        builder: (_, _) => const BootstrapPage(),
      ),
      GoRoute(
        path: AppRoutes.accountDisabled,
        builder: (_, _) => const AccountDisabledPage(),
      ),

      // ---- shared detail screens (pushed over either shell) ----
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, _) => const ProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.createVenue,
        builder: (_, _) => const VenueFormPage(),
      ),
      GoRoute(
        path: AppRoutes.venueDetail,
        builder: (_, state) =>
            VenueDetailPage(venueId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) =>
                VenueFormPage(venueId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'schedule',
            builder: (_, state) =>
                ScheduleActivityPage(venueId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'visit',
            builder: (_, state) =>
                RecordVisitPage(venueId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.activityDetail,
        builder: (_, state) =>
            ActivityDetailPage(activityId: state.pathParameters['id']!),
      ),

      // ---- employee shell ----
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(
          navigationShell: shell,
          destinations: const [
            ShellDestination(
              label: 'Home',
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard,
            ),
            ShellDestination(
              label: 'Venues',
              icon: Icons.stadium_outlined,
              selectedIcon: Icons.stadium,
            ),
            ShellDestination(
              label: 'Follow-ups',
              icon: Icons.event_repeat_outlined,
              selectedIcon: Icons.event_repeat,
            ),
            ShellDestination(
              label: 'Projects',
              icon: Icons.folder_outlined,
              selectedIcon: Icons.folder,
            ),
          ],
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.employeeHome,
              builder: (_, _) => const EmployeeDashboardPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.myVenues,
              builder: (_, _) => const VenueListPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.followUps,
              builder: (_, _) => const FollowUpsPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.myProjects,
              builder: (_, _) => const ProjectListPage(scopeToCurrentUser: true),
            ),
          ]),
        ],
      ),

      // ---- admin shell ----
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(
          navigationShell: shell,
          destinations: const [
            ShellDestination(
              label: 'Overview',
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard,
            ),
            ShellDestination(
              label: 'Venues',
              icon: Icons.stadium_outlined,
              selectedIcon: Icons.stadium,
            ),
            ShellDestination(
              label: 'Activity',
              icon: Icons.event_note_outlined,
              selectedIcon: Icons.event_note,
            ),
            ShellDestination(
              label: 'Projects',
              icon: Icons.folder_outlined,
              selectedIcon: Icons.folder,
            ),
            ShellDestination(
              label: 'Team',
              icon: Icons.groups_outlined,
              selectedIcon: Icons.groups,
            ),
          ],
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.adminDashboard,
              builder: (_, _) => const AdminDashboardPage(),
              routes: [
                GoRoute(
                  path: 'reports',
                  builder: (_, _) => const ReportsPage(),
                ),
                GoRoute(
                  path: 'visits',
                  builder: (_, _) => const VisitHistoryPage(),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.adminVenues,
              builder: (_, _) => const VenueListPage(scopeToCurrentUser: false),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.adminActivities,
              builder: (_, _) => const FollowUpsPage(orgWide: true),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.projects,
              builder: (_, _) => const ProjectListPage(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (_, _) => const ProjectFormPage(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (_, state) =>
                      ProjectDetailPage(projectId: state.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (_, state) =>
                          ProjectFormPage(projectId: state.pathParameters['id']!),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.employees,
              builder: (_, _) => const EmployeeListPage(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (_, _) => const CreateEmployeePage(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (_, state) =>
                      EmployeeDetailPage(employeeId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_outlined, size: 48),
              const SizedBox(height: 14),
              Text(
                'No screen matches ${state.uri}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => context.go(AppRoutes.splash),
                child: const Text('Go home'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Bridges a BLoC stream to go_router's [Listenable]-based refresh hook.
class _CubitRefreshListenable extends ChangeNotifier {
  _CubitRefreshListenable(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
