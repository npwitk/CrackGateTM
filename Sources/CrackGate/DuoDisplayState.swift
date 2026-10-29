import SwiftUI

/// Coarse hinge state, mirrored from `DeviceHinge.Status` so callers on iOS 26 can still name it.
public enum HingeStatus: Sendable, Equatable {
    case closed
    case partiallyOpen
    case fullyOpen
}

/// Where the hinge crosses the view.
public struct FoldLine: Sendable, Equatable {
    public enum Axis: Sendable, Equatable {
        /// The hinge runs top to bottom; the device is open like a book held upright.
        case vertical
        /// The hinge runs left to right; the device is open and rotated.
        case horizontal
    }

    public var axis: Axis
    /// `x` for a vertical fold, `y` for a horizontal one, in the view's coordinate space.
    public var position: CGFloat

    public init(axis: Axis, position: CGFloat) {
        self.axis = axis
        self.position = position
    }

    /// Asks the system for the fold's reserved region. Falls back to the centre of the
    /// longer side on devices without a hinge or on iOS earlier than 27.1.
    @MainActor
    public static func detect(in proxy: GeometryProxy) -> FoldLine {
        if #available(iOS 27.1, *) {
            let regions = proxy.reservedRegions(kind: .division, options: .includeInactive)
            if let region = regions.first, let fold = FoldLine(regionFrame: region.frame) {
                return fold
            }
        }
        return .centered(in: proxy.size)
    }

    /// Centre of the longer side, which is where the Duo's hinge sits in both orientations.
    public static func centered(in size: CGSize) -> FoldLine {
        if size.width >= size.height {
            FoldLine(axis: .vertical, position: size.width / 2)
        } else {
            FoldLine(axis: .horizontal, position: size.height / 2)
        }
    }

    init?(regionFrame frame: CGRect) {
        // An inactive division can report a zero-size frame; only trust one with a usable midpoint.
        guard frame.midX.isFinite, frame.midY.isFinite else { return nil }
        if frame.width < frame.height {
            guard frame.midX > 0 else { return nil }
            self.init(axis: .vertical, position: frame.midX)
        } else {
            guard frame.midY > 0 else { return nil }
            self.init(axis: .horizontal, position: frame.midY)
        }
    }
}

/// Everything the trigger needs to decide whether the app is on the open inner display.
struct DuoDisplayState: Equatable {
    var horizontalSizeClass: UserInterfaceSizeClass?
    var verticalSizeClass: UserInterfaceSizeClass?
    var hinge: HingeStatus?

    /// Regular in both axes rules out the outer display; an open hinge rules out everything that is not a Duo.
    var isInnerDisplayOpen: Bool {
        horizontalSizeClass == .regular
            && verticalSizeClass == .regular
            && (hinge == .fullyOpen || hinge == .partiallyOpen)
    }
}

/// One hinge update: the new status and how far the angle moved since the last one, in radians.
struct HingeReading: Equatable, Sendable {
    var status: HingeStatus?
    var angleDelta: Double
}

/// Feeds `onHingeChange` into a plain closure, gated on availability so the package builds for iOS 26.
struct HingeStatusReader: ViewModifier {
    let onChange: (HingeReading) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange { previous, current in
                let delta: Double
                if let old = previous.hinge, let new = current.hinge {
                    delta = new.angle.radians - old.angle.radians
                } else {
                    delta = 0
                }
                onChange(HingeReading(status: HingeStatus(current.hinge), angleDelta: delta))
            }
        } else {
            content
        }
    }
}

/// How hard the user is currently bending the crack. Decays after the last movement.
public struct HingeStress: Equatable, Sendable {
    /// When the last movement happened.
    public var date: Date
    /// 0…1 how hard it was pushed.
    public var magnitude: Double
    /// 0…1 level it settles to while the hinge stays partially open.
    public var floor: Double

    public init(date: Date = .now, magnitude: Double, floor: Double = 0) {
        self.date = date
        self.magnitude = magnitude
        self.floor = floor
    }

    /// Fold a hinge reading into the current stress. A nudge adds a pulse; a bend raises the floor.
    static func update(_ current: HingeStress?, with reading: HingeReading, at date: Date = .now) -> HingeStress? {
        let floor: Double = reading.status == .partiallyOpen ? 0.5 : 0
        let movement = abs(reading.angleDelta)
        if movement > 0.004 {
            // ~7° of movement is a full push; anything noticeable is at least a flicker.
            let magnitude = min(1, max(0.35, movement / 0.12))
            return HingeStress(date: date, magnitude: max(magnitude, current?.floor ?? 0), floor: floor)
        }
        guard var current else {
            return floor > 0 ? HingeStress(date: date, magnitude: floor, floor: floor) : nil
        }
        current.floor = floor
        return current
    }

    /// Current level, 0…1, as the pulse decays towards the floor.
    public func level(at date: Date) -> Double {
        let elapsed = max(0, date.timeIntervalSince(self.date))
        let decayed = magnitude * exp(-elapsed / 0.6)
        return min(1, max(floor, decayed))
    }
}

@available(iOS 27.1, *)
extension HingeStatus {
    init?(_ hinge: DeviceHinge?) {
        guard let hinge else { return nil }
        // `DeviceHinge.Status` is a struct with static members, so compare rather than switch.
        if hinge.status == .closed {
            self = .closed
        } else if hinge.status == .partiallyOpen {
            self = .partiallyOpen
        } else if hinge.status == .fullyOpen {
            self = .fullyOpen
        } else {
            return nil
        }
    }
}

extension View {
    /// Reports the hinge state of the device this view is displayed on.
    /// `nil` means there is no hinge, or the OS is older than iOS 27.1.
    public func onHingeStatusChange(_ action: @escaping (HingeStatus?) -> Void) -> some View {
        modifier(HingeStatusReader { action($0.status) })
    }
}
