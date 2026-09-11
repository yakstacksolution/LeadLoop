import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/follow_up_bloc.dart';

class FollowUpsPage extends StatelessWidget {
  const FollowUpsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FollowUpBloc, FollowUpState>(
      builder: (context, state) {
        final tasks = [...state.visibleOpenTasks]
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Follow-ups',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            for (final task in tasks) ...[
              _TaskTile(state: state, taskId: task.id),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.state, required this.taskId});

  final FollowUpState state;
  final String taskId;

  @override
  Widget build(BuildContext context) {
    final task = state.openTasks.firstWhere((item) => item.id == taskId);
    final customer = state.customers.firstWhere(
      (item) => item.id == task.customerId,
    );
    final product = state.products.firstWhere(
      (item) => item.id == task.productId,
    );
    final overdue = task.isOverdue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: overdue
                    ? const Color(0xFFFFEAE8)
                    : product.brandColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                overdue ? Icons.priority_high_rounded : Icons.schedule,
                color: overdue ? const Color(0xFFB42318) : product.brandColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(customer.businessName),
                  const SizedBox(height: 8),
                  Text(
                    task.nextAction,
                    style: const TextStyle(
                      color: Color(0xFF536460),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatDateTime(task.dueAt),
                          style: TextStyle(
                            color: overdue
                                ? const Color(0xFFB42318)
                                : const Color(0xFF00897B),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add_call, size: 18),
                        label: const Text('Add follow-up'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.month}/${value.day} at $hour:$minute';
  }
}
