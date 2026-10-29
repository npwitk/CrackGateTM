import SwiftUI

extension EnvironmentValues {
    /// `true` while a `crackGate` overlay is visible on an ancestor view.
    ///
    /// Use it to play along: show a fake "Software Update" card, a "Not you too…" toast,
    /// or a support link, only while the crack is on screen.
    @Entry public var crackGateIsActive: Bool = false
}
