import '../entities/customer.dart';
import '../entities/follow_up_task.dart';
import '../entities/product.dart';
import '../entities/timeline_entry.dart';

abstract class FollowUpRepository {
  Future<List<Product>> getProducts();
  Future<List<Customer>> getCustomers();
  Future<List<FollowUpTask>> getOpenTasks();
  Future<List<TimelineEntry>> getTimeline(String customerId);
}
