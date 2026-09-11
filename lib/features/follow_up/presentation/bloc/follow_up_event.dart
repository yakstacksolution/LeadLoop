part of 'follow_up_bloc.dart';

sealed class FollowUpEvent extends Equatable {
  const FollowUpEvent();

  @override
  List<Object?> get props => [];
}

final class FollowUpStarted extends FollowUpEvent {
  const FollowUpStarted();
}

final class ProductFilterChanged extends FollowUpEvent {
  const ProductFilterChanged(this.productId);

  final String? productId;

  @override
  List<Object?> get props => [productId];
}

final class NavigationTabChanged extends FollowUpEvent {
  const NavigationTabChanged(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}
