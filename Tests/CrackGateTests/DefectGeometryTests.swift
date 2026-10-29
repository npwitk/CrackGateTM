import Testing
import SwiftUI
@testable import CrackGate

@Suite("DefectGeometry")
struct DefectGeometryTests {
    let innerLandscape = CGSize(width: 951, height: 669)
    let fold = FoldLine(axis: .vertical, position: 475.5)

    @Test("Same seed draws the same crack")
    func deterministic() {
        let a = DefectGeometry(size: innerLandscape, fold: fold, seed: 42, spec: .classic)
        let b = DefectGeometry(size: innerLandscape, fold: fold, seed: 42, spec: .classic)
        #expect(a == b)
    }

    @Test("Different seeds draw different blobs")
    func seedsDiffer() {
        let a = DefectGeometry(size: innerLandscape, fold: fold, seed: 1, spec: .classic)
        let b = DefectGeometry(size: innerLandscape, fold: fold, seed: 2, spec: .classic)
        #expect(a.blobPoints != b.blobPoints)
    }

    @Test("Blob sits on the fold, lines reach the edges")
    func anchoring() {
        let geometry = DefectGeometry(size: innerLandscape, fold: fold, seed: 7, spec: .classic)
        #expect(geometry.blobCenter.x == 475.5)
        #expect(geometry.blobCenter.y > 669 * 0.5 && geometry.blobCenter.y < 669 * 0.75)
        #expect(geometry.horizontalLines.count == 3)
        for line in geometry.horizontalLines {
            #expect(line.minX == 475.5)
            #expect(line.maxX == 951)
        }
        let vertical = try! #require(geometry.verticalLine)
        #expect(vertical.maxY == 669)
        #expect(abs(vertical.midX - 475.5) < 0.01)
        #expect(geometry.creasePoints.first?.y == 0)
        #expect(geometry.creasePoints.last?.y == 669)
    }

    @Test("Horizontal fold swaps the axes")
    func horizontalFold() {
        let portrait = CGSize(width: 669, height: 951)
        let geometry = DefectGeometry(size: portrait, fold: FoldLine(axis: .horizontal, position: 475.5), seed: 7, spec: .classic)
        #expect(geometry.canonicalSize == CGSize(width: 951, height: 669))
        let crease = geometry.creasePath.boundingRect
        #expect(abs(crease.midY - 475.5) < 1)
        #expect(crease.width > 600)
        #expect(crease.height < 2)
    }

    @Test("Spreading progress clips the lines")
    func progress() {
        let geometry = DefectGeometry(size: innerLandscape, fold: fold, seed: 7, spec: .classic)
        let half = geometry.horizontalLineRects(progress: 0.5)
        #expect(abs(half[0].width - (951 - 475.5) / 2) < 0.01)
        #expect(geometry.horizontalLineRects(progress: 0)[0].width == 0)
        #expect(geometry.verticalLineRect(progress: 0)?.height == 0)
    }

    @Test("Stripes band has five rows, glitch rows span the width, crease stops at blob when asked")
    func stripes() {
        let geometry = DefectGeometry(size: innerLandscape, fold: fold, seed: 7, spec: .stripes)
        #expect(geometry.creasePoints.last?.y == 669)
        var short = CrackGateStyle.Spec.stripes
        short.creaseExtent = .aboveBlob
        let shortGeometry = DefectGeometry(size: innerLandscape, fold: fold, seed: 7, spec: short)
        #expect(shortGeometry.creasePoints.last?.y == shortGeometry.blobCenter.y)
        #expect(geometry.horizontalLines.count == 5)
        for row in geometry.glitchLineRects {
            #expect(row.minX == 0)
            #expect(row.maxX == 951)
        }
    }

    @Test("Trailing panel is the half beyond the fold")
    func trailingPanel() {
        let geometry = DefectGeometry(size: innerLandscape, fold: fold, seed: 7, spec: .stripes)
        #expect(geometry.trailingPanel == CGRect(x: 475.5, y: 0, width: 475.5, height: 669))
        let portrait = DefectGeometry(size: CGSize(width: 669, height: 951), fold: FoldLine(axis: .horizontal, position: 475.5), seed: 7, spec: .stripes)
        // A quarter turn, not a mirror: the half past the fold is the top half in panel space.
        let physical = Path(portrait.trailingPanel).applying(portrait.transform).boundingRect
        #expect(physical == CGRect(x: 0, y: 0, width: 669, height: 475.5))
        let row = Path(portrait.horizontalLines[0]).applying(portrait.transform).boundingRect
        #expect(row.maxY <= 475.5 + 0.01 && row.minY >= 0)
        let line = Path(portrait.verticalLine!).applying(portrait.transform).boundingRect
        #expect(line.maxX == 669)
    }

    @Test("Hinge stress: nudges pulse and decay, bends hold a floor, flat recovers")
    func hingeStress() {
        let t0 = Date(timeIntervalSinceReferenceDate: 1000)
        #expect(HingeStress.update(nil, with: HingeReading(status: .fullyOpen, angleDelta: 0.001), at: t0) == nil)
        let nudge = HingeStress.update(nil, with: HingeReading(status: .fullyOpen, angleDelta: 0.03), at: t0)
        #expect(nudge?.magnitude == 0.35)
        #expect(nudge?.level(at: t0) == 0.35)
        #expect(nudge!.level(at: t0.addingTimeInterval(3)) < 0.01)
        let push = HingeStress.update(nil, with: HingeReading(status: .fullyOpen, angleDelta: -0.2), at: t0)
        #expect(push?.magnitude == 1)
        let bend = HingeStress.update(push, with: HingeReading(status: .partiallyOpen, angleDelta: 0), at: t0)
        #expect(bend!.level(at: t0.addingTimeInterval(10)) == 0.5)
        let flat = HingeStress.update(bend, with: HingeReading(status: .fullyOpen, angleDelta: 0), at: t0)
        #expect(flat!.level(at: t0.addingTimeInterval(10)) < 0.01)
        var spec = CrackGateStyle.Spec.stripes
        spec.panelDim = .hinge
        let calm = (0..<2000).filter { AnimatedCrack.panelDim(tick: UInt64($0), seed: 1, spec: spec, stress: 0) > 0 }.count
        let stressed = (0..<2000).filter { AnimatedCrack.panelDim(tick: UInt64($0), seed: 1, spec: spec, stress: 1) > 0 }.count
        #expect(calm > 20 && calm < 400)
        #expect(stressed > calm * 3)
        #expect(stressed < 2000)  // still snaps back to normal now and then
    }

    @Test("Panel dim schedule: off is 0, constant is the opacity, flicker has an early episode")
    func panelDimSchedule() {
        var spec = CrackGateStyle.Spec.stripes
        #expect(AnimatedCrack.panelDim(tick: 13, seed: 1, spec: spec) == 0)
        spec.panelDim = .constant
        #expect(AnimatedCrack.panelDim(tick: 13, seed: 1, spec: spec) == 0.55)
        spec.panelDim = .flicker
        let early = (12..<16).map { AnimatedCrack.panelDim(tick: UInt64($0), seed: 1, spec: spec) }
        #expect(early.contains { $0 > 0 })
        #expect(early.allSatisfy { $0 <= 0.55 })
        #expect(AnimatedCrack.panelDim(tick: 0, seed: 1, spec: spec) == 0)
        let dimmedTicks = (0..<2000).filter { AnimatedCrack.panelDim(tick: UInt64($0), seed: 1, spec: spec) > 0 }.count
        #expect(dimmedTicks > 20 && dimmedTicks < 400)
    }

    @Test("Subtle spec has no blob or lines, only dead pixels")
    func subtle() {
        let geometry = DefectGeometry(size: innerLandscape, fold: fold, seed: 7, spec: .subtle)
        #expect(geometry.blobPoints.isEmpty)
        #expect(geometry.horizontalLines.isEmpty)
        #expect(geometry.verticalLine == nil)
        #expect(geometry.deadPixels.count == 4)
    }
}

@Suite("FoldLine")
struct FoldLineTests {
    @Test("Centred fallback follows the longer side")
    func centered() {
        #expect(FoldLine.centered(in: CGSize(width: 951, height: 669)) == FoldLine(axis: .vertical, position: 475.5))
        #expect(FoldLine.centered(in: CGSize(width: 669, height: 951)) == FoldLine(axis: .horizontal, position: 475.5))
    }

    @Test("Region frames map to a fold, zero frames are rejected")
    func regionFrames() {
        #expect(FoldLine(regionFrame: CGRect(x: 470, y: 0, width: 11, height: 669)) == FoldLine(axis: .vertical, position: 475.5))
        #expect(FoldLine(regionFrame: CGRect(x: 0, y: 470, width: 669, height: 11)) == FoldLine(axis: .horizontal, position: 475.5))
        #expect(FoldLine(regionFrame: .zero) == nil)
    }
}

@Suite("DeviceSpace")
struct DeviceSpaceTests {
    // Window → panel transforms for a 951×669 panel, as UIKit's coordinate conversion would give them.
    let identity = CGAffineTransform.identity
    /// Window rotated a quarter turn clockwise relative to the panel (window is 669×951).
    let quarter = CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: 669)
    let half = CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: 951, ty: 669)

    @Test("Identity when the window is the panel")
    func identityCase() {
        let space = DeviceSpace(windowSize: CGSize(width: 951, height: 669), toDevice: identity, deviceSize: CGSize(width: 951, height: 669))
        #expect(space.quarterTurns == 0)
        #expect(space.deviceFold(from: FoldLine(axis: .vertical, position: 475.5)) == FoldLine(axis: .vertical, position: 475.5))
    }

    @Test("A rotated window maps its fold back onto the same physical fold")
    func rotated() {
        let space = DeviceSpace(windowSize: CGSize(width: 669, height: 951), toDevice: quarter, deviceSize: CGSize(width: 951, height: 669))
        #expect(space.deviceFold(from: FoldLine(axis: .horizontal, position: 475.5)) == FoldLine(axis: .vertical, position: 475.5))
        let flipped = DeviceSpace(windowSize: CGSize(width: 951, height: 669), toDevice: half, deviceSize: CGSize(width: 951, height: 669))
        #expect(flipped.quarterTurns == 2)
        #expect(flipped.deviceFold(from: FoldLine(axis: .vertical, position: 475.5)) == FoldLine(axis: .vertical, position: 475.5))
    }

    @Test("A physical point lands on the same panel pixel from any window")
    func physicalPointIsStable() {
        let panelPoint = CGPoint(x: 600, y: 400)
        let upright = DeviceSpace(windowSize: CGSize(width: 951, height: 669), toDevice: identity, deviceSize: CGSize(width: 951, height: 669))
        let turned = DeviceSpace(windowSize: CGSize(width: 669, height: 951), toDevice: quarter, deviceSize: CGSize(width: 951, height: 669))
        let flipped = DeviceSpace(windowSize: CGSize(width: 951, height: 669), toDevice: half, deviceSize: CGSize(width: 951, height: 669))
        for space in [upright, turned, flipped] {
            let inWindow = panelPoint.applying(space.toWindow)
            #expect(inWindow.x >= 0 && inWindow.x <= space.windowSize.width)
            #expect(inWindow.y >= 0 && inWindow.y <= space.windowSize.height)
            let back = inWindow.applying(space.toDevice)
            #expect(abs(back.x - 600) < 0.01 && abs(back.y - 400) < 0.01)
        }
    }
}

@Suite("Trigger")
struct TriggerTests {
    @Test("Inner display requires regular size classes and an open hinge")
    func innerDisplay() {
        func state(_ h: UserInterfaceSizeClass?, _ v: UserInterfaceSizeClass?, _ hinge: HingeStatus?) -> Bool {
            DuoDisplayState(horizontalSizeClass: h, verticalSizeClass: v, hinge: hinge).isInnerDisplayOpen
        }
        #expect(state(.regular, .regular, .fullyOpen))
        #expect(state(.regular, .regular, .partiallyOpen))
        #expect(!state(.regular, .regular, .closed))
        #expect(!state(.regular, .regular, nil))
        #expect(!state(.compact, .regular, .fullyOpen))
        #expect(!state(.regular, .compact, .fullyOpen))
    }

    @Test("Trigger resolution")
    func resolve() {
        #expect(CrackGateTrigger.innerDisplay.resolve(innerDisplayOpen: true))
        #expect(!CrackGateTrigger.innerDisplay.resolve(innerDisplayOpen: false))
        #expect(CrackGateTrigger.always.resolve(innerDisplayOpen: false))
        #expect(!CrackGateTrigger.never.resolve(innerDisplayOpen: true))
        #expect(CrackGateTrigger.when(true).resolve(innerDisplayOpen: false))
    }

    @Test("Random style is stable per seed")
    func randomStyle() {
        #expect(CrackGateStyle.random.spec(seed: 9) == CrackGateStyle.random.spec(seed: 9))
        let picks = Set((0..<40).map { seed -> Int in
            let spec = CrackGateStyle.random.spec(seed: UInt64(seed))
            return [CrackGateStyle.Spec.stripes, .classic, .whiteBar, .rainbow, .subtle].firstIndex(of: spec) ?? -1
        })
        #expect(!picks.contains(-1))
        #expect(picks.count > 1)
    }
}
