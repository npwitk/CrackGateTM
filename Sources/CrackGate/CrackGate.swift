import SwiftUI

public enum CrackGate {
    /// The seed used when you do not pass one. Change the seed to get a different unit.
    public static let defaultSeed: UInt64 = 0xC4AC_6A7E

}

/// Where the crack is drawn.
public enum CrackGatePresentation: Sendable, Equatable {
    /// A passthrough window above the app's own windows, so it also covers sheets and alerts.
    /// Falls back to `.inline` when no window scene is available, such as in previews.
    case window
    /// A plain overlay on the modified view.
    case inline
}

extension View {
    /// Fakes an iPhone Duo "Crackgate" inner-display defect on top of this view.
    ///
    /// Apply it to your root view so the crack covers the whole window:
    ///
    ///     ContentView()
    ///         .crackGate()
    ///
    /// By default the crack only appears on an iPhone Duo whose hinge is open, so it is
    /// drawn on the inner display where the real thing happens. Everyone else sees nothing.
    ///
    /// The crack lives in its own window above sheets, alerts and full-screen covers, because a
    /// dead row of pixels does not care what you are presenting. Pass `presentation: .inline`
    /// to keep it as a plain overlay on this view instead.
    ///
    /// - Parameters:
    ///   - style: Which unit you got. `.stripes` is the video everyone shared.
    ///   - trigger: When it may appear. `.innerDisplay` by default; `.always` for demos.
    ///   - onset: Whether it is there immediately, after a delay, or spreads out from the fold.
    ///   - presentation: Own window above everything (default) or an inline overlay.
    ///   - seed: Fixes the exact shape. Same seed, same crack, every launch.
    public func crackGate(
        _ style: CrackGateStyle = .stripes,
        trigger: CrackGateTrigger = .innerDisplay,
        onset: CrackGateOnset = .immediate,
        presentation: CrackGatePresentation = .window,
        seed: UInt64 = CrackGate.defaultSeed
    ) -> some View {
        modifier(CrackGateModifier(style: style, trigger: trigger, onset: onset, presentation: presentation, seed: seed))
    }
}

struct CrackGateModifier: ViewModifier {
    let style: CrackGateStyle
    let trigger: CrackGateTrigger
    let onset: CrackGateOnset
    let presentation: CrackGatePresentation
    let seed: UInt64

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var hinge: HingeStatus?
    @State private var hingeStress: HingeStress?
    @State private var armed = false
    @State private var windowScene: UIWindowScene?
    @State private var windowController = CrackGateWindowController()

    private var shouldShow: Bool {
        let state = DuoDisplayState(
            horizontalSizeClass: horizontalSizeClass,
            verticalSizeClass: verticalSizeClass,
            hinge: hinge
        )
        return trigger.resolve(innerDisplayOpen: state.isInnerDisplayOpen)
    }

    private var isActive: Bool { shouldShow && armed }

    private var usesWindow: Bool { presentation == .window && windowScene != nil }

    /// Everything that changes what the window should draw.
    private struct Signature: Equatable {
        var style: CrackGateStyle
        var seed: UInt64
        var onset: CrackGateOnset
        var presentation: CrackGatePresentation
        var hingeStress: HingeStress?
    }

    private var signature: Signature {
        Signature(style: style, seed: seed, onset: onset, presentation: presentation, hingeStress: hingeStress)
    }

    private var overlay: CrackGateOverlay {
        let spreading: Duration? = if case .spreading(let duration) = onset { duration } else { nil }
        return CrackGateOverlay(style: style, seed: seed, spreading: spreading, hingeStress: hingeStress)
    }

    func body(content: Content) -> some View {
        content
            .environment(\.crackGateIsActive, isActive)
            .background {
                WindowSceneReader { windowScene = $0 }
            }
            .overlay {
                if isActive, !usesWindow {
                    overlay
                }
            }
            .modifier(HingeStatusReader { reading in
                hinge = reading.status
                hingeStress = HingeStress.update(hingeStress, with: reading)
            })
            .task(id: shouldShow) { await runOnset() }
            .onChange(of: isActive, initial: true) { _, _ in syncWindow() }
            .onChange(of: windowScene) { _, _ in syncWindow() }
            .onChange(of: signature) { _, _ in syncWindow() }
            .onDisappear { windowController.hide() }
    }

    private func syncWindow() {
        if isActive, usesWindow, let windowScene {
            windowController.show(overlay, in: windowScene)
        } else {
            windowController.hide()
        }
    }

    @MainActor
    private func runOnset() async {
        armed = false
        guard shouldShow else { return }

        switch onset {
        case .immediate, .spreading:
            armed = true

        case .after(let delay):
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            armed = true
        }
    }
}

#Preview("Stripes, forced") {
    ZStack {
        LinearGradient(colors: [.blue.opacity(0.5), .orange.opacity(0.4)], startPoint: .top, endPoint: .bottom)
        Text("12:34").font(.system(size: 120, weight: .thin, design: .rounded))
    }
    .ignoresSafeArea()
    .crackGate(.stripes, trigger: .always, presentation: .inline)
}

#Preview("White bar, dark") {
    ZStack {
        Color.black
        Text("13:34").font(.system(size: 120, weight: .thin, design: .rounded)).foregroundStyle(.white.opacity(0.8))
    }
    .ignoresSafeArea()
    .crackGate(.whiteBar, trigger: .always, presentation: .inline)
}
