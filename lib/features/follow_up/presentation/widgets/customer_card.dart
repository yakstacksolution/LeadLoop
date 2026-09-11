import 'package:flutter/material.dart';

import '../../domain/entities/customer.dart';
import '../../domain/entities/product.dart';
import 'status_chip.dart';

class CustomerCard extends StatelessWidget {
  const CustomerCard({
    super.key,
    required this.customer,
    required this.product,
  });

  final Customer customer;
  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        customer.businessName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF536460),
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(status: customer.status),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(label: product.name, color: product.brandColor),
                _MetaChip(
                  label: _priorityLabel(customer.priority),
                  color: _priorityColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.schedule, size: 18, color: Color(0xFF71817D)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    customer.nextFollowUpAt == null
                        ? 'No next action'
                        : 'Next: ${_formatDateTime(customer.nextFollowUpAt!)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: customer.isOverdue
                          ? const Color(0xFFB42318)
                          : const Color(0xFF536460),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color get _priorityColor {
    return switch (customer.priority) {
      Priority.high => const Color(0xFFB42318),
      Priority.normal => const Color(0xFF2563EB),
      Priority.low => const Color(0xFF536460),
    };
  }

  static String _priorityLabel(Priority priority) {
    return switch (priority) {
      Priority.low => 'Low priority',
      Priority.normal => 'Normal priority',
      Priority.high => 'High priority',
    };
  }

  static String _formatDateTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.month}/${value.day} $hour:$minute';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
