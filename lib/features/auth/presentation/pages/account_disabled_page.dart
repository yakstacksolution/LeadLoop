import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/auth_cubit.dart';
import '../widgets/auth_scaffold.dart';

/// Shown when a signed-in account's profile says `status: disabled`.
///
/// The security rules already refuse this account's reads and writes; this
/// screen just explains why rather than leaving the user at an empty list.
class AccountDisabledPage extends StatelessWidget {
  const AccountDisabledPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Account disabled',
      subtitle: 'Your access has been turned off by an administrator.',
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, color: AppColors.warning),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your records are safe and nothing has been deleted. Ask your '
                  'administrator to re-enable the account, then sign in again.',
                  style: TextStyle(height: 1.45, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: () => context.read<AuthCubit>().signOut(),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}
