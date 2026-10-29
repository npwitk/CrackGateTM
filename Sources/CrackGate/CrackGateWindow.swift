import SwiftUI
import UIKit

/// A window that lets every touch fall through to the app underneath.
final class CrackGatePassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }
}

/// Hosts the crack in its own window above sheets, alerts, and full-screen covers,
/// which is where a real dead row of pixels would be.
@MainActor
final class CrackGateWindowController {
    private var window: CrackGatePassthroughWindow?
    private var host: UIHostingController<CrackGateOverlay>?

    func show(_ overlay: CrackGateOverlay, in scene: UIWindowScene) {
        if let host, window?.windowScene === scene {
            host.rootView = overlay
            return
        }
        hide()

        let host = UIHostingController(rootView: overlay)
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false

        let window = CrackGatePassthroughWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.isUserInteractionEnabled = false
        window.rootViewController = host
        window.isHidden = false

        self.host = host
        self.window = window
    }

    func hide() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        host = nil
    }
}

/// Reports the window scene the attached SwiftUI view ends up in.
struct WindowSceneReader: UIViewRepresentable {
    let onChange: (UIWindowScene?) -> Void

    func makeUIView(context: Context) -> SceneReportingView {
        let view = SceneReportingView()
        view.onChange = onChange
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: SceneReportingView, context: Context) {
        uiView.onChange = onChange
    }

    final class SceneReportingView: UIView {
        var onChange: ((UIWindowScene?) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onChange?(window?.windowScene)
        }
    }
}
