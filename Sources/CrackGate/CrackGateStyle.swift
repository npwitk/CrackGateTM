import SwiftUI

/// Which "unit" you got.
public enum CrackGateStyle: Sendable, Equatable {
    /// Full-height crease, a small blob, a tight bright green/white/blue band out to the right edge,
    /// and a thin lime line down to the bottom. The home screen photo.
    case stripes
    /// Dark crease, black dead-pixel blob on the fold, three cyan lines to the right edge,
    /// a bright green line down to the bottom. The photo everyone shared.
    case classic
    /// One thick glowing white bar from the fold to the edge and a thin white line down.
    /// The dark lock-screen photo.
    case whiteBar
    /// A single multicolour stuck-pixel bar that shimmers. The Software Update photo.
    case rainbow
    /// Just the crease and a few dead pixels. For people who like to be asked "did you notice?".
    case subtle
    /// One of the five above, chosen by the seed so it stays the same for a given user.
    case random
    /// Bring your own.
    case custom(Spec)

    /// Everything the renderer needs. All presets are expressed as one of these.
    public struct Spec: Sendable, Equatable {
        /// `nil` picks black in light mode and white in dark mode, like the photos.
        public var creaseColor: Color?
        public var creaseOpacity: Double
        public var creaseWidth: CGFloat
        /// Whether the crease runs the full height or stops at the blob, like a crack that ended there.
        public var creaseExtent: CreaseExtent
        /// 0 removes the blob, 1 is the size in the photos.
        public var blobScale: CGFloat
        /// Colours of the stuck lines that run from the fold to the edge.
        /// With `horizontalLineGradient` on, they form one gradient along the line;
        /// otherwise line `i` takes colour `i % count`.
        public var horizontalLineColors: [Color]
        public var horizontalLineGradient: Bool
        public var horizontalLineCount: Int
        public var horizontalLineThickness: CGFloat
        public var horizontalLineSpacing: CGFloat
        /// Blur radius of the bloom behind the stuck lines. 0 disables it.
        public var glowRadius: CGFloat
        /// `nil` removes the line that runs from the blob to the bottom edge.
        public var verticalLineColor: Color?
        public var verticalLineWidth: CGFloat
        /// A thin edge drawn either side of the vertical line, for the lime-with-dark-rim look.
        public var verticalLineBorderColor: Color?
        /// Lone dead pixels scattered along the crease.
        public var deadPixelCount: Int
        /// Subtle opacity jitter on the stuck lines. Ignored under Reduce Motion.
        public var flickers: Bool
        /// The half of the panel beyond the fold flickering dark. `.flicker` is short random
        /// episodes on a timer. `.hinge` is the same, but flexing the device makes it worse and a
        /// bent hinge keeps it going until the phone is flat. `.constant` just leaves it dim.
        public var panelDim: PanelDim
        /// How dark the dimmed half gets, 0…1. The video is about 0.55.
        public var panelDimOpacity: Double

        public init(
            creaseColor: Color? = nil,
            creaseOpacity: Double = 0.85,
            creaseWidth: CGFloat = 1.2,
            creaseExtent: CreaseExtent = .full,
            blobScale: CGFloat = 1,
            horizontalLineColors: [Color] = [CrackGateStyle.cyan],
            horizontalLineGradient: Bool = false,
            horizontalLineCount: Int = 3,
            horizontalLineThickness: CGFloat = 1.5,
            horizontalLineSpacing: CGFloat = 3,
            glowRadius: CGFloat = 2,
            verticalLineColor: Color? = CrackGateStyle.green,
            verticalLineWidth: CGFloat = 2,
            verticalLineBorderColor: Color? = nil,
            deadPixelCount: Int = 0,
            flickers: Bool = true,
            panelDim: PanelDim = .off,
            panelDimOpacity: Double = 0.55
        ) {
            self.creaseColor = creaseColor
            self.creaseOpacity = creaseOpacity
            self.creaseWidth = creaseWidth
            self.creaseExtent = creaseExtent
            self.blobScale = blobScale
            self.horizontalLineColors = horizontalLineColors
            self.horizontalLineGradient = horizontalLineGradient
            self.horizontalLineCount = horizontalLineCount
            self.horizontalLineThickness = horizontalLineThickness
            self.horizontalLineSpacing = horizontalLineSpacing
            self.glowRadius = glowRadius
            self.verticalLineColor = verticalLineColor
            self.verticalLineWidth = verticalLineWidth
            self.verticalLineBorderColor = verticalLineBorderColor
            self.deadPixelCount = deadPixelCount
            self.flickers = flickers
            self.panelDim = panelDim
            self.panelDimOpacity = panelDimOpacity
        }

        public enum PanelDim: Sendable, Equatable {
            case off
            /// Timer flicker, made worse by hinge movement. Needs iOS 27.1 for the hinge part.
            case hinge
            /// Random short flickers on a timer, one soon after appearing.
            case flicker
            case constant
        }

        public enum CreaseExtent: Sendable, Equatable {
            case full
            case aboveBlob
        }

        /// The home screen photo: full crease, a tight bright band at the fold with green above and
        /// blue below, and a thin lime line straight down.
        public static let stripes = Spec(
            creaseOpacity: 0.9,
            creaseWidth: 1.2,
            creaseExtent: .full,
            blobScale: 0.5,
            horizontalLineColors: [
                Color(red: 0.30, green: 0.95, blue: 0.40),
                Color(red: 0.80, green: 1, blue: 0.98),
                Color(red: 0.96, green: 1, blue: 1),
                Color(red: 0.55, green: 0.95, blue: 1),
                Color(red: 0.30, green: 0.55, blue: 1),
            ],
            horizontalLineCount: 5,
            horizontalLineThickness: 1.6,
            horizontalLineSpacing: 0.6,
            glowRadius: 2.5,
            verticalLineColor: Color(red: 0.85, green: 1, blue: 0.30),
            verticalLineWidth: 2,
            verticalLineBorderColor: Color(red: 0.30, green: 0.40, blue: 0.10),
            flickers: true
        )

        /// The photo everyone shared.
        public static let classic = Spec()

        public static let whiteBar = Spec(
            creaseOpacity: 0.6,
            creaseWidth: 1,
            blobScale: 0.6,
            horizontalLineColors: [.white],
            horizontalLineCount: 1,
            horizontalLineThickness: 8,
            glowRadius: 6,
            verticalLineColor: .white,
            verticalLineWidth: 1.5,
            flickers: false
        )

        public static let rainbow = Spec(
            creaseOpacity: 0.7,
            blobScale: 0.8,
            horizontalLineColors: [CrackGateStyle.cyan, Color(red: 1, green: 0.2, blue: 0.9), Color(red: 1, green: 0.95, blue: 0.3), .white],
            horizontalLineGradient: true,
            horizontalLineCount: 1,
            horizontalLineThickness: 5,
            glowRadius: 4,
            verticalLineColor: nil,
            flickers: true
        )

        public static let subtle = Spec(
            creaseOpacity: 0.5,
            creaseWidth: 1,
            blobScale: 0,
            horizontalLineCount: 0,
            glowRadius: 0,
            verticalLineColor: nil,
            deadPixelCount: 4,
            flickers: false
        )

    }

    /// Stuck-pixel cyan.
    public static let cyan = Color(red: 0, green: 0.94, blue: 1)
    /// Stuck-pixel green.
    public static let green = Color(red: 0.22, green: 1, blue: 0.08)


    /// The same unit, with the half beyond the fold browning out when the hinge moves.
    ///
    ///     .crackGate(.stripes.panelDim())
    public func panelDim(_ mode: Spec.PanelDim = .hinge, opacity: Double = 0.55, seed: UInt64 = CrackGate.defaultSeed) -> CrackGateStyle {
        var spec = self.spec(seed: seed)
        spec.panelDim = mode
        spec.panelDimOpacity = opacity
        return .custom(spec)
    }

    /// Resolves the preset into a concrete spec. `.random` uses the seed so a user always gets the same unit.
    public func spec(seed: UInt64) -> Spec {
        switch self {
        case .stripes: Spec.stripes
        case .classic: Spec.classic
        case .whiteBar: Spec.whiteBar
        case .rainbow: Spec.rainbow
        case .subtle: Spec.subtle
        case .custom(let spec): spec
        case .random:
            {
                var generator = SeededGenerator(seed: seed ^ 0x5EED_5EED_5EED_5EED)
                let presets: [CrackGateStyle] = [.stripes, .classic, .whiteBar, .rainbow, .subtle]
                return presets[Int.random(in: 0..<presets.count, using: &generator)].spec(seed: seed)
            }()
        }
    }
}
