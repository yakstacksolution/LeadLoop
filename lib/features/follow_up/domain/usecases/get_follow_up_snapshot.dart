import '../entities/customer.dart';
import '../entities/follow_up_task.dart';
import '../entities/product.dart';
import '../repositories/follow_up_repository.dart';

class FollowUpSnapshot {
  const FollowUpSnapshot({
    required this.products,
    required this.customers,
    required this.openTasks,
  });

  final List<Product> products;
  final List<Customer> customers;
  final List<FollowUpTask> openTasks;
}

class GetFollowUpSnapshot {
  const GetFollowUpSnapshot(this.repository);

  final FollowUpRepository repository;

  Future<FollowUpSnapshot> call() async {
    final results = await Future.wait([
      repository.getProducts(),
      repository.getCustomers(),
      repository.getOpenTasks(),
    ]);

    return FollowUpSnapshot(
      products: results[0] as List<Product>,
      customers: results[1] as List<Customer>,
      openTasks: results[2] as List<FollowUpTask>,
    );
  }
}
