import Flutter
import UIKit

/// The iOS splash screen, held up until the app says it is ready.
///
/// `LaunchScreen.storyboard` is torn down the moment the app's window exists,
/// which on a cold start is well before Dart has run. This rebuilds the same
/// artwork as a real view over the Flutter view and takes it down — with a
/// short cross-fade — when Dart calls `dismiss` over the splash channel, which
/// happens once the persisted session has been resolved.
///
/// Built from the same asset catalogue entry the storyboard uses, so the two
/// are identical and the handover is invisible.
final class SplashScreen {

    /// Must match `NativeSplash` on the Dart side.
    private static let channelName = "com.np.hamrofutsal.lead/splash"

    /// Backstop: a splash that never comes down would be a frozen app.
    private static let timeout: TimeInterval = 6

    private var overlay: UIView?

    /// Covers [window]'s root view with the launch artwork and starts
    /// listening for the dismiss call.
    func show(over window: UIWindow) {
        guard let rootView = window.rootViewController?.view else { return }

        let container = UIView(frame: rootView.bounds)
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.backgroundColor = .white

        let logo = UIImageView(image: UIImage(named: "LaunchImage"))
        logo.contentMode = .scaleAspectFit
        logo.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(logo)

        NSLayoutConstraint.activate([
            logo.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            logo.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            logo.widthAnchor.constraint(equalToConstant: 200),
            logo.heightAnchor.constraint(equalToConstant: 200),
        ])

        rootView.addSubview(container)
        overlay = container

        listen(on: window)
        DispatchQueue.main.asyncAfter(deadline: .now() + SplashScreen.timeout) {
            [weak self] in self?.dismiss()
        }
    }

    private func listen(on window: UIWindow) {
        guard let controller = window.rootViewController as? FlutterViewController
        else {
            // No Flutter engine to hear from; do not strand the overlay.
            dismiss()
            return
        }

        let channel = FlutterMethodChannel(
            name: SplashScreen.channelName,
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { [weak self] call, result in
            guard call.method == "dismiss" else {
                result(FlutterMethodNotImplemented)
                return
            }
            self?.dismiss()
            result(nil)
        }
    }

    /// Fades the overlay out and drops it. Safe to call more than once.
    func dismiss() {
        guard let overlay else { return }
        self.overlay = nil

        UIView.animate(
            withDuration: 0.25,
            animations: { overlay.alpha = 0 },
            completion: { _ in overlay.removeFromSuperview() }
        )
    }
}
