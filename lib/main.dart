import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/app_theme.dart';
import 'features/follow_up/data/repositories/in_memory_follow_up_repository.dart';
import 'features/follow_up/domain/repositories/follow_up_repository.dart';
import 'features/follow_up/domain/usecases/get_follow_up_snapshot.dart';
import 'features/follow_up/presentation/bloc/follow_up_bloc.dart';
import 'features/follow_up/presentation/pages/leadloop_home_page.dart';

void main() {
  runApp(LeadLoopApp(repository: InMemoryFollowUpRepository()));
}

class LeadLoopApp extends StatelessWidget {
  const LeadLoopApp({super.key, required this.repository});

  final FollowUpRepository repository;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: repository,
      child: BlocProvider(
        create: (_) =>
            FollowUpBloc(getFollowUpSnapshot: GetFollowUpSnapshot(repository))
              ..add(const FollowUpStarted()),
        child: MaterialApp(
          title: 'LeadLoop',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const LeadLoopHomePage(),
        ),
      ),
    );
  }
}
