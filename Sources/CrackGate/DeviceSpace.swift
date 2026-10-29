import SwiftUI
import UIKit

/// The crack is a hardware defect, so it is generated in *panel space*: the screen's fixed
/// coordinate space, which never rotates. The window's space is mapped into it with UIKit's own
/// coordinate conversion, so whatever iOS calls the current orientation, the crack stays on the
/// same physical pixels.
struct DeviceSpace: Equatable {
    let windowSize: CGSize
    /// Window points → panel points.
    let toDevice: CGAffineTransform
    /// Size of the panel-space canvas.
    let deviceSize: CGSize

    init(windowSize: CGSize, toDevice: CGAffineTransform = .identity, deviceSize: CGSize? = nil) {
        self.windowSize = windowSize
        self.toDevice = toDevice
        self.deviceSize = deviceSize ?? windowSize
    }

    /// Panel points → window points.
    var toWindow: CGAffineTransform { toDevice.inverted() }

    /// Quarter turns clockwise from panel space to the window, for diagnostics.
    var quarterTurns: Int {
        let t = toWindow
        if abs(t.a - 1) < 0.01 { return 0 }
        if abs(t.b - 1) < 0.01 { return 1 }
        if abs(t.a + 1) < 0.01 { return 2 }
        return 3
    }

    /// The fold, as seen in the window, expressed in panel space where it never moves.
    func deviceFold(from windowFold: FoldLine) -> FoldLine {
        let a: CGPoint
        let b: CGPoint
        switch windowFold.axis {
        case .vertical:
            a = CGPoint(x: windowFold.position, y: 0)
            b = CGPoint(x: windowFold.position, y: 100)
        case .horizontal:
            a = CGPoint(x: 0, y: windowFold.position)
            b = CGPoint(x: 100, y: windowFold.position)
        }
        let da = a.applying(toDevice)
        let db = b.applying(toDevice)
        if abs(da.x - db.x) < 0.001 {
            return FoldLine(axis: .vertical, position: da.x)
        } else {
            return FoldLine(axis: .horizontal, position: da.y)
        }
    }
}

/// What the panel reader found: how this view's window maps onto the physical panel.
struct PanelMapping: Equatable {
    var toPanel: CGAffineTransform = .identity
    var panelSize: CGSize? = nil
}

/// Reports, on every layout pass, the transform from the attached view's coordinate space to the
/// screen's fixed (physical) coordinate space.
struct PanelSpaceReader: UIViewRepresentable {
    let onChange: (PanelMapping) -> Void

    func makeUIView(context: Context) -> ReportingView {
        let view = ReportingView()
        view.onChange = onChange
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: ReportingView, context: Context) {
        uiView.onChange = onChange
        uiView.report()
    }

    final class ReportingView: UIView {
        var onChange: ((PanelMapping) -> Void)?
        private var last: PanelMapping?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        func report() {
            guard let screen = window?.windowScene?.screen else { return }
            let fixed = screen.fixedCoordinateSpace
            let origin = convert(CGPoint.zero, to: fixed)
            let unitX = convert(CGPoint(x: 1, y: 0), to: fixed)
            let unitY = convert(CGPoint(x: 0, y: 1), to: fixed)
            let transform = CGAffineTransform(
                a: unitX.x - origin.x, b: unitX.y - origin.y,
                c: unitY.x - origin.x, d: unitY.y - origin.y,
                tx: origin.x, ty: origin.y
            )
            let mapping = PanelMapping(toPanel: transform, panelSize: fixed.bounds.size)
            guard mapping != last else { return }
            last = mapping
            onChange?(mapping)
        }
    }
}

/// Reports the interface orientation of the window this view lives in, on every layout pass.
struct InterfaceOrientationReader: UIViewRepresentable {
    let onChange: (UIInterfaceOrientation) -> Void

    func makeUIView(context: Context) -> ReportingView {
        let view = ReportingView()
        view.onChange = onChange
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: ReportingView, context: Context) {
        uiView.onChange = onChange
        uiView.report()
    }

    final class ReportingView: UIView {
        var onChange: ((UIInterfaceOrientation) -> Void)?
        private var last: UIInterfaceOrientation?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        func report() {
            guard let orientation = window?.windowScene?.effectiveGeometry.interfaceOrientation, orientation != last else { return }
            last = orientation
            onChange?(orientation)
        }
    }
}

extension View {
    /// Reports the interface orientation of the window this view is in. Handy for diagnostics.
    public func onInterfaceOrientationChange(_ action: @escaping (UIInterfaceOrientation) -> Void) -> some View {
        background(InterfaceOrientationReader(onChange: action))
    }
}
