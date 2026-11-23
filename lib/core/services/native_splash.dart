import 'package:flutter/services.dart';

/// The Dart end of the native splash screen.
///
/// The splash itself is entirely native — `Theme.SplashScreen` on Android and
/// a Swift overlay on iOS — and both sides hold it up until this says the app
/// is ready. That is later than Flutter's first frame: the first frame is a
/// blank router waiting on the persisted session, and dismissing there would
/// flash an empty screen before the dashboard or the login form.
abstract final class NativeSplash {
  static const _channel = MethodChannel('com.np.hamrofutsal.lead/splash');

  static bool _dismissed = false;

  /// Tells the platform to take the splash down. Safe to call repeatedly;
  /// only the first call crosses the channel.
  static Future<void> dismiss() async {
    if (_dismissed) return;
    _dismissed = true;

    try {
      await _channel.invokeMethod<void>('dismiss');
    } on MissingPluginException {
      // Web, desktop, or a host that has no splash to dismiss.
    } catch (_) {
      // A splash that will not come down must never take the app with it.
    }
  }
}
