import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';

import '../../features/activities/data/repositories/activity_repository_impl.dart';
import '../../features/activities/domain/repositories/activity_repository.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_cubit.dart';
import '../../features/contacts/data/repositories/contact_repository_impl.dart';
import '../../features/contacts/domain/repositories/contact_repository.dart';
import '../../features/employees/data/datasources/account_provisioner.dart';
import '../../features/employees/data/repositories/employee_repository_impl.dart';
import '../../features/employees/domain/repositories/employee_repository.dart';
import '../../features/projects/data/repositories/project_repository_impl.dart';
import '../../features/projects/domain/repositories/project_repository.dart';
import '../../features/venues/data/repositories/venue_repository_impl.dart';
import '../../features/venues/domain/repositories/venue_repository.dart';
import '../../features/visits/data/repositories/visit_repository_impl.dart';
import '../../features/visits/domain/repositories/visit_repository.dart';
import '../constants/firestore_collections.dart';
import '../services/location_service.dart';
import '../services/place_search_service.dart';

final sl = GetIt.instance;

/// Wires the object graph.
///
/// Repositories are lazy singletons (they hold no per-screen state); BLoCs are
/// registered as factories so each screen gets its own and disposes it.
/// [AuthCubit] is the one exception — it is the app-wide session.
Future<void> configureDependencies({
  FirebaseAuth? auth,
  FirebaseFirestore? firestore,
  FirebaseFunctions? functions,
}) async {
  final firebaseAuth = auth ?? FirebaseAuth.instance;
  final firebaseFirestore = firestore ?? FirebaseFirestore.instance;
  final firebaseFunctions = functions ??
      FirebaseFunctions.instanceFor(region: CloudFunctionNames.region);

  // ---- Firebase SDKs ----
  sl
    ..registerLazySingleton<FirebaseAuth>(() => firebaseAuth)
    ..registerLazySingleton<FirebaseFirestore>(() => firebaseFirestore)
    ..registerLazySingleton<FirebaseFunctions>(() => firebaseFunctions);

  // ---- Services ----
  sl
    ..registerLazySingleton<LocationService>(() => const LocationService())
    ..registerLazySingleton<PlaceSearchService>(() => const PlaceSearchService());

  // ---- Repositories ----
  sl
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        auth: sl<FirebaseAuth>(),
        firestore: sl<FirebaseFirestore>(),
      ),
    )
    ..registerLazySingleton<ProjectRepository>(
      () => ProjectRepositoryImpl(firestore: sl<FirebaseFirestore>()),
    )
    ..registerLazySingleton<VenueRepository>(
      () => VenueRepositoryImpl(firestore: sl<FirebaseFirestore>()),
    )
    ..registerLazySingleton<ContactRepository>(
      () => ContactRepositoryImpl(firestore: sl<FirebaseFirestore>()),
    )
    ..registerLazySingleton<ActivityRepository>(
      () => ActivityRepositoryImpl(firestore: sl<FirebaseFirestore>()),
    )
    ..registerLazySingleton<VisitRepository>(
      () => VisitRepositoryImpl(firestore: sl<FirebaseFirestore>()),
    )
    ..registerLazySingleton<AccountProvisioner>(() => AccountProvisioner())
    ..registerLazySingleton<EmployeeRepository>(
      () => EmployeeRepositoryImpl(
        firestore: sl<FirebaseFirestore>(),
        provisioner: sl<AccountProvisioner>(),
        currentUserId: () => sl<FirebaseAuth>().currentUser?.uid ?? '',
      ),
    );

  // ---- Session ----
  sl.registerLazySingleton<AuthCubit>(() => AuthCubit(sl<AuthRepository>()));
}

/// Tears the graph down. Used between widget tests.
Future<void> resetDependencies() => sl.reset();
