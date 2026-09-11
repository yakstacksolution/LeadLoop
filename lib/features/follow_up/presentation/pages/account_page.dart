import 'package:flutter/material.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: Color(0xFFEAF5F3),
                  child: Text('M', style: TextStyle(color: Color(0xFF00897B))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mina Tamang',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const Text('Admin - Hamro Futsal, Kavelo'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _AccountAction(
          icon: Icons.inventory_2_outlined,
          label: 'Products',
        ),
        const _AccountAction(
          icon: Icons.group_add_outlined,
          label: 'Employees',
        ),
        const _AccountAction(
          icon: Icons.assignment_ind_outlined,
          label: 'Assignments',
        ),
        const _AccountAction(
          icon: Icons.insights_outlined,
          label: 'Team reports',
        ),
        const _AccountAction(icon: Icons.logout, label: 'Sign out'),
      ],
    );
  }
}

class _AccountAction extends StatelessWidget {
  const _AccountAction({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF00897B)),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }
}
