package com.np.hamrofutsal.lead

import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter UI and owns the splash screen.
 *
 * The splash is the platform's own — `Theme.SplashScreen`, with the icon and
 * white background declared in res/values/styles.xml — rather than a Flutter
 * widget. It is what the OS draws from the moment the process starts, before
 * any Dart has run.
 *
 * Two things would otherwise cut it short:
 *
 *  * the system dismisses it as soon as the activity's first frame is ready,
 *    which on a cold start is several hundred milliseconds before Flutter has
 *    anything to show; and
 *  * Flutter's own first frame is a blank router still waiting on the
 *    persisted session.
 *
 * So it is held with [setKeepOnScreenCondition] until Dart calls `dismiss`
 * over [SPLASH_CHANNEL], which happens once the session is resolved and the
 * router knows where to go. [SPLASH_TIMEOUT_MS] is the backstop: a splash
 * that never comes down would be a frozen app.
 */
class MainActivity : FlutterActivity() {

    private var keepSplash = true

    override fun onCreate(savedInstanceState: Bundle?) {
        // Must run before super.onCreate: the splash is installed as part of
        // the activity's theme resolution.
        installSplashScreen().setKeepOnScreenCondition { keepSplash }
        super.onCreate(savedInstanceState)

        window.decorView.postDelayed({ keepSplash = false }, SPLASH_TIMEOUT_MS)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPLASH_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "dismiss" -> {
                        keepSplash = false
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val SPLASH_CHANNEL = "com.np.hamrofutsal.lead/splash"
        const val SPLASH_TIMEOUT_MS = 6000L
    }
}
