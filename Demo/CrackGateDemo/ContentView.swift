import SwiftUI
import CrackGate

struct ContentView: View {
    @State private var preset: Preset = .stripes
    @State private var force = true
    @State private var spreading = false
    @State private var dimPanel = false
    @State private var seed: UInt64 = CrackGate.defaultSeed
    /// `SIMCTL_CHILD_CRACKGATE_DEMO_CLEAN=1 xcrun simctl launch …` launches with no crack and no panel,
    /// for capturing a clean screen.
    private static let launchedClean = ProcessInfo.processInfo.environment["CRACKGATE_DEMO_CLEAN"] == "1"
    /// `SIMCTL_CHILD_CRACKGATE_DEMO_HIDE_CONTROLS=1` launches with the crack but no panel.
    private static let launchedHidden = ProcessInfo.processInfo.environment["CRACKGATE_DEMO_HIDE_CONTROLS"] == "1"
    @State private var showControls = !(ContentView.launchedClean || ContentView.launchedHidden)
    @State private var hinge: HingeStatus?
    @State private var windowSize: CGSize = .zero
    @State private var fold = FoldLine(axis: .vertical, position: 0)
    @State private var showSheet = false
    @State private var orientation: UIInterfaceOrientation = .unknown

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    enum Preset: String, CaseIterable, Identifiable {
        case stripes = "Stripes", classic = "Classic", whiteBar = "White bar", rainbow = "Rainbow", subtle = "Subtle", random = "Random"
        var id: String { rawValue }
        var style: CrackGateStyle {
            switch self {
            case .stripes: .stripes
            case .classic: .classic
            case .whiteBar: .whiteBar
            case .rainbow: .rainbow
            case .subtle: .subtle
            case .random: .random
            }
        }
    }

    var body: some View {
        ZStack {
            Wallpaper()
            if showControls {
                controls
            }
        }
        .ignoresSafeArea()
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.size, initial: true) { _, size in
                        windowSize = size
                        fold = FoldLine.detect(in: proxy)
                    }
            }
            .ignoresSafeArea()
        }
        .onTapGesture(count: 2) { showControls.toggle() }
        .onHingeStatusChange { hinge = $0 }
        .onInterfaceOrientationChange { orientation = $0 }
        .sheet(isPresented: $showSheet) {
            NavigationStack {
                List {
                    Section("Personal") {
                        Label("John Appleseed", systemImage: "person.crop.circle")
                    }
                    Section("Teams") {
                        Label("Appleseed Orchards", systemImage: "leaf")
                        Label("Cupertino Hinge Repair", systemImage: "wrench.and.screwdriver")
                    }
                }
                .navigationTitle("Accounts")
            }
            .presentationDetents([.medium])
        }
        .crackGate(
            dimPanel ? preset.style.panelDim(seed: seed) : preset.style,
            trigger: Self.launchedClean ? .never : (force ? .always : .innerDisplay),
            onset: spreading ? .spreading(.seconds(2)) : .immediate,
            seed: seed
        )
        .id("\(spreading)")
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CrackGate™ demo").font(.headline)
            Picker("Unit", selection: $preset) {
                ForEach(Preset.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Force (any device)", isOn: $force)
            Toggle("Spread in over 2 s", isOn: $spreading)
            Toggle("Right panel flickers", isOn: $dimPanel)
            Stepper("Seed \(seed)", value: $seed, in: 0...UInt64(Int32.max), step: 1)
            Button("Present a sheet (crack stays on top)") { showSheet = true }
            ActiveBadge()
            Text("size \(Int(windowSize.width))×\(Int(windowSize.height)) · \(sizeClassText) · hinge \(hingeText) · fold \(fold.axis == .vertical ? "x" : "y")=\(fold.position, format: .number.precision(.fractionLength(1))) · \(orientationText)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Text("Double-tap the wallpaper to hide these controls.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: 420)
        .glassEffect(in: .rect(cornerRadius: 20))
        .padding(.horizontal, 24)
        .padding(.top, 72)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var sizeClassText: String {
        let h = horizontalSizeClass == .regular ? "R" : "C"
        let v = verticalSizeClass == .regular ? "R" : "C"
        return "\(h)×\(v)"
    }

    private var orientationText: String {
        switch orientation {
        case .portrait: "portrait"
        case .portraitUpsideDown: "upsideDown"
        case .landscapeLeft: "landscapeLeft"
        case .landscapeRight: "landscapeRight"
        default: "unknown"
        }
    }

    private var hingeText: String {
        switch hinge {
        case .closed: "closed"
        case .partiallyOpen: "partial"
        case .fullyOpen: "open"
        case nil: "none"
        }
    }
}

/// Reads the environment value the library sets while the crack is showing.
private struct ActiveBadge: View {
    @Environment(\.crackGateIsActive) private var cracked

    var body: some View {
        Label(cracked ? "crack is showing" : "crack is hidden", systemImage: cracked ? "exclamationmark.triangle.fill" : "checkmark.circle")
            .font(.caption.weight(.semibold))
            .foregroundStyle(cracked ? .orange : .secondary)
    }
}

/// Drop any image into `Assets.xcassets/Wallpaper.imageset` and it is used; otherwise the dunes below.
private struct Wallpaper: View {
    var body: some View {
        if UIImage(named: "Wallpaper") != nil {
            GeometryReader { proxy in
                Image("Wallpaper")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
        } else {
            DunesWallpaper()
        }
    }
}

/// Sky, a mountain ridge, and two dunes, all in code. No wallpaper assets to license.
private struct DunesWallpaper: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.42, green: 0.65, blue: 0.84), Color(red: 0.80, green: 0.80, blue: 0.75)],
                    startPoint: .top, endPoint: .bottom
                )
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.58))
                    p.addLine(to: CGPoint(x: w * 0.12, y: h * 0.47))
                    p.addLine(to: CGPoint(x: w * 0.26, y: h * 0.53))
                    p.addLine(to: CGPoint(x: w * 0.40, y: h * 0.42))
                    p.addLine(to: CGPoint(x: w * 0.55, y: h * 0.49))
                    p.addLine(to: CGPoint(x: w * 0.68, y: h * 0.40))
                    p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.50))
                    p.addLine(to: CGPoint(x: w, y: h * 0.45))
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.addLine(to: CGPoint(x: 0, y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [Color(red: 0.36, green: 0.33, blue: 0.31), Color(red: 0.22, green: 0.20, blue: 0.19)], startPoint: .top, endPoint: .bottom))
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.62))
                    p.addQuadCurve(to: CGPoint(x: w * 0.55, y: h * 0.70), control: CGPoint(x: w * 0.25, y: h * 0.50))
                    p.addQuadCurve(to: CGPoint(x: w, y: h * 0.56), control: CGPoint(x: w * 0.85, y: h * 0.78))
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.addLine(to: CGPoint(x: 0, y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [Color(red: 0.93, green: 0.86, blue: 0.72), Color(red: 0.80, green: 0.70, blue: 0.54)], startPoint: .top, endPoint: .bottom))
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h))
                    p.addQuadCurve(to: CGPoint(x: w, y: h * 0.78), control: CGPoint(x: w * 0.45, y: h * 0.95))
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [Color(red: 0.88, green: 0.78, blue: 0.60), Color(red: 0.74, green: 0.62, blue: 0.46)], startPoint: .top, endPoint: .bottom))
            }
        }
    }
}

#Preview {
    ContentView()
}
