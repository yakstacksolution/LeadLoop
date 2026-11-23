import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// What sits under the native splash while the session is being resolved.
///
/// Deliberately empty. The splash is drawn by the platform — the Android
/// SplashScreen API and a Swift overlay on iOS — and stays up until
/// `NativeSplash.dismiss()` is called, so nothing here is ever seen. It is a
/// plain white surface only so that the frame behind the splash matches it,
/// and so a failure to dismiss leaves a clean screen rather than a black one.
class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: AppColors.surface, child: SizedBox.expand());
}
