import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/customer.dart';
import '../../domain/entities/follow_up_task.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/get_follow_up_snapshot.dart';

part 'follow_up_event.dart';
part 'follow_up_state.dart';

class FollowUpBloc extends Bloc<FollowUpEvent, FollowUpState> {
  FollowUpBloc({required this.getFollowUpSnapshot})
    : super(const FollowUpState()) {
    on<FollowUpStarted>(_onStarted);
    on<ProductFilterChanged>(_onProductFilterChanged);
    on<NavigationTabChanged>(_onNavigationTabChanged);
  }

  final GetFollowUpSnapshot getFollowUpSnapshot;

  Future<void> _onStarted(
    FollowUpStarted event,
    Emitter<FollowUpState> emit,
  ) async {
    emit(state.copyWith(status: FollowUpStatus.loading));
    try {
      final snapshot = await getFollowUpSnapshot();
      emit(
        state.copyWith(
          status: FollowUpStatus.success,
          products: snapshot.products,
          customers: snapshot.customers,
          openTasks: snapshot.openTasks,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: FollowUpStatus.failure,
          errorMessage: 'Could not load follow-up data.',
        ),
      );
    }
  }

  void _onProductFilterChanged(
    ProductFilterChanged event,
    Emitter<FollowUpState> emit,
  ) {
    emit(state.copyWith(selectedProductId: () => event.productId));
  }

  void _onNavigationTabChanged(
    NavigationTabChanged event,
    Emitter<FollowUpState> emit,
  ) {
    emit(state.copyWith(selectedTab: event.index));
  }
}
