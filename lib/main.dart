import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injector.dart';
import 'core/services/native_splash.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_cubit.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await configureDependencies();

  runApp(const HamroFutsalApp());
}

class HamroFutsalApp extends StatefulWidget {
  const HamroFutsalApp({super.key});

  @override
  State<HamroFutsalApp> createState() => _HamroFutsalAppState();
}

class _HamroFutsalAppState extends State<HamroFutsalApp> {
  late final AuthCubit _authCubit = sl<AuthCubit>();
  late final _router = createRouter(_authCubit);

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authCubit,
      // The native splash stays up until the session has been resolved and
      // the router has somewhere to send the user — dismissing it on
      // Flutter's first frame would flash an empty screen first.
      child: BlocListener<AuthCubit, AuthState>(
        listenWhen: (previous, current) =>
            previous.status == AuthStatus.unknown &&
            current.status != AuthStatus.unknown,
        listener: (_, _) => NativeSplash.dismiss(),
        child: MaterialApp.router(
          // Shown in the Android task switcher, so it matches the launcher.
          title: 'Futsal Lead',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          scrollBehavior: const _AppScrollBehavior(),
          routerConfig: _router,
        ),
      ),
    );
  }
}

/// Dragging any list puts the keyboard away, so it never covers search
/// results or the rest of a form.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  ScrollViewKeyboardDismissBehavior getKeyboardDismissBehavior(
    BuildContext context,
  ) => ScrollViewKeyboardDismissBehavior.onDrag;
}
