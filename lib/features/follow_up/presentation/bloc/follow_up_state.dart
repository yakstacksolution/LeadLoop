part of 'follow_up_bloc.dart';

enum FollowUpStatus { initial, loading, success, failure }

class FollowUpState extends Equatable {
  const FollowUpState({
    this.status = FollowUpStatus.initial,
    this.products = const [],
    this.customers = const [],
    this.openTasks = const [],
    this.selectedProductId,
    this.selectedTab = 0,
    this.errorMessage,
  });

  final FollowUpStatus status;
  final List<Product> products;
  final List<Customer> customers;
  final List<FollowUpTask> openTasks;
  final String? selectedProductId;
  final int selectedTab;
  final String? errorMessage;

  List<Customer> get visibleCustomers {
    final productId = selectedProductId;
    if (productId == null) return customers;
    return customers
        .where((customer) => customer.productId == productId)
        .toList();
  }

  List<FollowUpTask> get visibleOpenTasks {
    final productId = selectedProductId;
    if (productId == null) return openTasks;
    return openTasks.where((task) => task.productId == productId).toList();
  }

  List<FollowUpTask> get overdueTasks =>
      visibleOpenTasks.where((task) => task.isOverdue).toList();

  List<FollowUpTask> get dueTodayTasks {
    final now = DateTime.now();
    return visibleOpenTasks.where((task) {
      return task.dueAt.year == now.year &&
          task.dueAt.month == now.month &&
          task.dueAt.day == now.day &&
          !task.isOverdue;
    }).toList();
  }

  List<Customer> get customersWithoutNextAction => visibleCustomers
      .where((customer) => customer.nextFollowUpAt == null)
      .toList();

  FollowUpState copyWith({
    FollowUpStatus? status,
    List<Product>? products,
    List<Customer>? customers,
    List<FollowUpTask>? openTasks,
    String? Function()? selectedProductId,
    int? selectedTab,
    String? errorMessage,
  }) {
    return FollowUpState(
      status: status ?? this.status,
      products: products ?? this.products,
      customers: customers ?? this.customers,
      openTasks: openTasks ?? this.openTasks,
      selectedProductId: selectedProductId != null
          ? selectedProductId()
          : this.selectedProductId,
      selectedTab: selectedTab ?? this.selectedTab,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    products,
    customers,
    openTasks,
    selectedProductId,
    selectedTab,
    errorMessage,
  ];
}
