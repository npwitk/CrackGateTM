import SwiftUI

/// The crack as a plain view, for apps that want to place it themselves.
///
/// It fills whatever space it is given, ignores the safe area, and never intercepts touches.
/// Prefer the `crackGate` modifier unless you need manual control.
public struct CrackGateOverlay: View {
    public var style: CrackGateStyle
    public var seed: UInt64
    /// `nil` asks the system for the hinge's reserved region and falls back to the centre.
    public var fold: FoldLine?
    /// When set, the stuck lines grow out from the fold over this duration on appear.
    public var spreading: Duration?
    /// Flash a full-width burst of stuck rows for a moment when the view appears,
    /// like the panel re-initialising as the device opens.
    public var glitchesOnAppear: Bool
    /// How hard the hinge is being flexed right now. Drives `panelDim == .hinge`.
    /// The `crackGate` modifier feeds this from the real hinge; pass your own for manual control.
    public var hingeStress: HingeStress?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var progress: Double = 0
    @State private var glitching = false
    @State private var panel = PanelMapping()

    public init(
        style: CrackGateStyle = .stripes,
        seed: UInt64 = CrackGate.defaultSeed,
        fold: FoldLine? = nil,
        spreading: Duration? = nil,
        glitchesOnAppear: Bool = true,
        hingeStress: HingeStress? = nil
    ) {
        self.style = style
        self.seed = seed
        self.fold = fold
        self.spreading = spreading
        self.glitchesOnAppear = glitchesOnAppear
        self.hingeStress = hingeStress
    }

    public var body: some View {
        AnimatedCrack(
            style: style,
            seed: seed,
            fold: fold,
            progress: progress,
            glitching: glitching,
            hingeStress: hingeStress,
            panel: panel,
            reduceMotion: reduceMotion,
            colorScheme: colorScheme
        )
        .background(PanelSpaceReader { panel = $0 })
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            if glitchesOnAppear, !reduceMotion {
                glitching = true
                try? await Task.sleep(for: .milliseconds(220))
                glitching = false
            }
            if let spreading, !reduceMotion {
                withAnimation(.easeOut(duration: spreading.timeInterval)) {
                    progress = 1
                }
            } else {
                progress = 1
            }
        }
    }
}

/// Resolves geometry per size and interpolates `progress` for the spreading onset.
struct AnimatedCrack: View, Animatable {
    var style: CrackGateStyle
    var seed: UInt64
    var fold: FoldLine?
    var progress: Double
    var glitching: Bool
    var hingeStress: HingeStress?
    var panel: PanelMapping
    var reduceMotion: Bool
    var colorScheme: ColorScheme

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private static let flickerEpoch = Date()

    var body: some View {
        GeometryReader { proxy in
            let spec = style.spec(seed: seed)
            let windowFold = fold ?? FoldLine.detect(in: proxy)
            // Build the crack where the panel is, not where the UI is.
            let space = DeviceSpace(windowSize: proxy.size, toDevice: panel.toPanel, deviceSize: panel.panelSize)
            let geometry = DefectGeometry(size: space.deviceSize, fold: space.deviceFold(from: windowFold), seed: seed, spec: spec)
            let toWindow = space.toWindow
            let animates = !reduceMotion && (spec.flickers || spec.panelDim == .flicker || spec.panelDim == .hinge)
            if animates {
                TimelineView(.periodic(from: Self.flickerEpoch, by: 0.12)) { timeline in
                    let tick = Self.tick(at: timeline.date)
                    let stress = Self.stressLevel(hingeStress, at: timeline.date, spec: spec)
                    CrackGateCanvas(
                        geometry: geometry,
                        spec: spec,
                        progress: progress,
                        glitching: glitching || stress > 0.85,
                        flicker: spec.flickers ? Self.flicker(tick: tick, seed: seed) : 1,
                        panelDim: Self.panelDim(tick: tick, seed: seed, spec: spec, stress: stress),
                        colorScheme: colorScheme,
                        windowTransform: toWindow
                    )
                }
            } else {
                let stress = Self.stressLevel(hingeStress, at: .now, spec: spec)
                CrackGateCanvas(
                    geometry: geometry,
                    spec: spec,
                    progress: progress,
                    glitching: glitching,
                    flicker: 1,
                    panelDim: Self.panelDim(tick: 0, seed: seed, spec: spec, stress: stress),
                    colorScheme: colorScheme,
                    windowTransform: toWindow
                )
            }
        }
    }

    static let tickInterval: TimeInterval = 0.12

    static func tick(at date: Date) -> UInt64 {
        UInt64(max(0, date.timeIntervalSince(flickerEpoch)) / tickInterval)
    }

    /// Mostly solid, with the occasional dip, like a panel that is not quite sure it is alive.
    static func flicker(tick: UInt64, seed: UInt64) -> Double {
        var generator = SeededGenerator(seed: seed ^ (tick &* 0x9E37_79B9))
        let roll = Double.random(in: 0...1, using: &generator)
        return roll < 0.8 ? 1 : Double.random(in: 0.55...0.92, using: &generator)
    }

    /// 0…1 how hard the hinge is being flexed, or 0 when the spec does not care.
    static func stressLevel(_ stress: HingeStress?, at date: Date, spec: CrackGateStyle.Spec) -> Double {
        guard spec.panelDim == .hinge, let stress else { return 0 }
        return stress.level(at: date)
    }

    /// Brown-outs of the far half, by mode. Never a steady dim: the panel strobes between dark and
    /// normal, in short episodes every few seconds. In `.hinge` mode, moving the hinge makes the
    /// episodes more frequent, longer and darker; a bent hinge keeps it misbehaving until flat.
    static func panelDim(tick: UInt64, seed: UInt64, spec: CrackGateStyle.Spec, stress: Double = 0) -> Double {
        switch spec.panelDim {
        case .off:
            return 0
        case .constant:
            return spec.panelDimOpacity
        case .flicker, .hinge:
            let stress = spec.panelDim == .hinge ? min(1, max(0, stress)) : 0

            // Ticks are grouped into 3 s windows; each window may hold one short episode.
            let windowLength: UInt64 = 25
            let window = tick / windowLength
            let offset = tick % windowLength
            var windowGenerator = SeededGenerator(seed: seed ^ (window &* 0xC2B2_AE35) ^ 0xD1F7)
            let hasEpisode = window == 0 || Double.random(in: 0...1, using: &windowGenerator) < 0.45
            let start = window == 0 ? 12 : UInt64.random(in: 0...(windowLength - 5), using: &windowGenerator)
            let length = UInt64.random(in: 2...4, using: &windowGenerator)
            var inEpisode = hasEpisode && offset >= start && offset < start + length

            // Hinge stress adds its own misbehaviour on top of the schedule.
            var tickGenerator = SeededGenerator(seed: seed ^ (tick &* 0x85EB_CA6B))
            if stress > 0.05, Double.random(in: 0...1, using: &tickGenerator) < stress * 0.9 {
                inEpisode = true
            }
            guard inEpisode else { return 0 }

            // Even mid-episode the panel sometimes snaps back to normal for a tick.
            let backToNormal = Double.random(in: 0...1, using: &tickGenerator) < (0.3 - 0.2 * stress)
            if backToNormal { return 0 }
            let depth = 0.7 + 0.3 * stress
            return spec.panelDimOpacity * depth * Double.random(in: 0.85...1, using: &tickGenerator)
        }
    }
}
