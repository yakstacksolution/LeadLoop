import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../../../shared/widgets/state_views.dart';
import '../bloc/auth_cubit.dart';
import '../widgets/auth_scaffold.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final ok = await context.read<AuthCubit>().sendPasswordReset(_emailController.text);
    if (ok && mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final busy = state.isSubmitting;

        return AuthScaffold(
          title: 'Reset password',
          subtitle: _sent
              ? 'Check your inbox for the reset link.'
              : 'We will email you a link to set a new password.',
          children: [
            if (_sent)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const InlineMessage(
                    message: 'If an account exists for that address, a reset link '
                        'is on its way. The link expires after a short while.',
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('Back to sign in'),
                  ),
                ],
              )
            else
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
                      controller: _emailController,
                      label: 'Email',
                      prefixIcon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                      enabled: !busy,
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 18),
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
                          : const Text('Send reset link'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: busy ? null : () => context.pop(),
                      child: const Text('Back to sign in'),
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
