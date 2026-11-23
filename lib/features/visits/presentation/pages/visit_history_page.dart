import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../domain/entities/visit.dart';
import '../../domain/repositories/visit_repository.dart';
import '../widgets/visit_tile.dart';

/// Visit history for one person — the signed-in user by default, or a
/// specific employee when an admin opens it from their profile.
class VisitHistoryPage extends StatefulWidget {
  const VisitHistoryPage({super.key, this.employeeId});

  final String? employeeId;

  @override
  State<VisitHistoryPage> createState() => _VisitHistoryPageState();
}

class _VisitHistoryPageState extends State<VisitHistoryPage> {
  Stream<List<Visit>>? _visits;

  @override
  Widget build(BuildContext context) {
    final uid =
        widget.employeeId ?? context.select((AuthCubit cubit) => cubit.state.uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Visit history')),
      body: StreamBuilder<List<Visit>>(
        stream: _visits ??= sl<VisitRepository>()
            .watchForEmployee(uid ?? '', limit: 100),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(failure: mapError(snapshot.error!));
          }
          if (!snapshot.hasData) return const SkeletonList();

          final visits = snapshot.data!;
          if (visits.isEmpty) {
            return const EmptyView(
              icon: Icons.not_listed_location_outlined,
              title: 'No visits recorded',
              message: 'Visits recorded from a venue screen appear here.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
            itemCount: visits.length,
            itemBuilder: (context, index) {
              final visit = visits[index];
              return VisitTile(
                visit: visit,
                showVenue: true,
                onTap: () => context.push(AppRoutes.venueDetailFor(visit.venueId)),
              );
            },
          );
        },
      ),
    );
  }
}
