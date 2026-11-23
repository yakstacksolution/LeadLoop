import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../../../shared/widgets/state_views.dart';
import '../bloc/auth_cubit.dart';
import '../widgets/auth_scaffold.dart';

/// One-time creation of the very first administrator.
///
/// Reached only when the signed-in account has no profile document, which on a
/// freshly provisioned project means nobody has claimed the admin role yet.
/// The `bootstrapFirstAdmin` Cloud Function re-checks that server-side and
/// refuses once any admin exists, so this screen cannot be used to escalate.
class BootstrapPage extends StatefulWidget {
  const BootstrapPage({super.key});

  @override
  State<BootstrapPage> createState() => _BootstrapPageState();
}

class _BootstrapPageState extends State<BootstrapPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    await context.read<AuthCubit>().bootstrapFirstAdmin(
          fullName: _nameController.text,
          phone: _phoneController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final busy = state.isSubmitting;

        return AuthScaffold(
          title: 'Set up your workspace',
          subtitle: 'This account has no profile yet. Claim the administrator '
              'role to finish setting up Hamro Futsal.',
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.failure != null) ...[
                    InlineMessage.error(message: state.failure!.message),
                    const SizedBox(height: 16),
                  ],
                  AppTextField(
                    controller: _nameController,
                    label: 'Your full name',
                    prefixIcon: Icons.person_outline,
                    textInputAction: TextInputAction.next,
                    validator: (value) => Validators.minLength(value, 2, 'Full name'),
                    enabled: !busy,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _phoneController,
                    label: 'Phone (optional)',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: Validators.optionalPhone,
                    enabled: !busy,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: busy ? null : _submit,
                    child: busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Become administrator'),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Only works while no administrator exists. If someone has '
                    'already set this up, ask them to create your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: busy ? null : () => context.read<AuthCubit>().signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
