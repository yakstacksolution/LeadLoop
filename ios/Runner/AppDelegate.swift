import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

    private let splash = SplashScreen()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let started = super.application(application, didFinishLaunchingWithOptions: launchOptions)

        // The storyboard is gone as soon as the window exists; this keeps the
        // same artwork up until Dart says the app is ready. See
        // SplashScreen.swift.
        if let window = window {
            splash.show(over: window)
        }

        return started
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }
}
