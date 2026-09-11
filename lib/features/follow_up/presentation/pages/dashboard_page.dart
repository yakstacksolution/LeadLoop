import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/follow_up_bloc.dart';
import '../widgets/customer_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FollowUpBloc, FollowUpState>(
      builder: (context, state) {
        final recent = state.visibleCustomers.take(2).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ProductSelector(state: state),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Overdue',
                    value: state.overdueTasks.length.toString(),
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFB42318),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    label: 'Due today',
                    value: state.dueTodayTasks.length.toString(),
                    icon: Icons.today_outlined,
                    color: const Color(0xFF00897B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Upcoming',
                    value: state.visibleOpenTasks.length.toString(),
                    icon: Icons.event_available_outlined,
                    color: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    label: 'No action',
                    value: state.customersWithoutNextAction.length.toString(),
                    icon: Icons.assignment_late_outlined,
                    color: const Color(0xFF7A4E00),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _SectionTitle(
              title: 'Recently assigned',
              action: TextButton.icon(
                onPressed: () => context.read<FollowUpBloc>().add(
                  const NavigationTabChanged(1),
                ),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('View all'),
              ),
            ),
            const SizedBox(height: 10),
            for (final customer in recent) ...[
              CustomerCard(
                customer: customer,
                product: state.products.firstWhere(
                  (product) => product.id == customer.productId,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _ProductSelector extends StatelessWidget {
  const _ProductSelector({required this.state});

  final FollowUpState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All My Products'),
            selected: state.selectedProductId == null,
            onSelected: (_) {
              context.read<FollowUpBloc>().add(
                const ProductFilterChanged(null),
              );
            },
          ),
          const SizedBox(width: 8),
          for (final product in state.products) ...[
            ChoiceChip(
              label: Text(product.name),
              selected: state.selectedProductId == product.id,
              onSelected: (_) {
                context.read<FollowUpBloc>().add(
                  ProductFilterChanged(product.id),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 14),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF10201D),
              ),
            ),
            Text(label, style: const TextStyle(color: Color(0xFF536460))),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.action});

  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        action,
      ],
    );
  }
}
