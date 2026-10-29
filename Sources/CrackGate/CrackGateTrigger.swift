import Foundation

/// Decides when the crack is allowed to appear.
public enum CrackGateTrigger: Sendable, Equatable {
    /// Only on an iPhone Duo whose hinge is open, so the app is on the 7.6" inner display.
    /// Never fires on other devices, on the outer display, or on iOS earlier than 27.1.
    case innerDisplay
    /// Always show. For previews, demos, and screenshots.
    case always
    /// Never show. Handy for a remote kill switch.
    case never
    /// Show while the bound value is `true`, on any device.
    case when(Bool)

    func resolve(innerDisplayOpen: Bool) -> Bool {
        switch self {
        case .innerDisplay: innerDisplayOpen
        case .always: true
        case .never: false
        case .when(let flag): flag
        }
    }
}

/// How the crack arrives once the trigger says yes.
public enum CrackGateOnset: Sendable, Equatable {
    /// Already there when the view appears.
    case immediate
    /// Appears all at once after a delay. Long enough that the user has stopped looking for it.
    case after(Duration)
    /// Stuck-pixel lines grow out from the fold over the duration.
    /// Collapses to `.immediate` when Reduce Motion is on.
    case spreading(Duration)
}

extension Duration {
    var timeInterval: TimeInterval {
        let parts = components
        return TimeInterval(parts.seconds) + TimeInterval(parts.attoseconds) / 1e18
    }
}
