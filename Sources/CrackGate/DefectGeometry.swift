import SwiftUI

/// The shapes of one broken unit, generated from a seed so it never moves between launches.
///
/// Everything is computed in a *canonical* space where the fold is vertical. `transform`
/// maps that space onto the view when the fold is actually horizontal.
public struct DefectGeometry: Sendable, Equatable {
    /// Size of the view the crack is drawn in.
    public let size: CGSize
    public let fold: FoldLine
    /// Width and height of the canonical space (swapped from `size` for a horizontal fold).
    public let canonicalSize: CGSize
    /// `x` of the fold in canonical space.
    public let foldPosition: CGFloat

    /// Polyline down the fold with a little wobble.
    public let creasePoints: [CGPoint]
    /// Jagged polygon of dead pixels sitting on the fold. Empty when the spec has no blob.
    public let blobPoints: [CGPoint]
    public let blobCenter: CGPoint
    /// Lowest `y` of the blob; the vertical line starts here.
    public let blobBottom: CGFloat
    /// Stuck lines from the blob to the right edge, full length.
    public let horizontalLines: [CGRect]
    /// Stuck line from the blob to the bottom edge, full length.
    public let verticalLine: CGRect?
    /// Lone dead pixels along the crease.
    public let deadPixels: [CGRect]

    public init(size: CGSize, fold: FoldLine, seed: UInt64, spec: CrackGateStyle.Spec) {
        self.size = size
        self.fold = fold

        let canonical = fold.axis == .vertical ? size : CGSize(width: size.height, height: size.width)
        canonicalSize = canonical
        // For a horizontal fold the canonical space is rotated a quarter turn (see `transform`),
        // so the fold's y in panel space is `canonical.width - x` in canonical space.
        foldPosition = fold.axis == .vertical ? fold.position : canonical.width - fold.position
        let width = canonical.width
        let height = canonical.height
        let foldX = fold.position

        var generator = SeededGenerator(seed: seed)

        // Blob: an ellipse on the fold, 55–70 % of the way down, with jittered radii.
        let centerFraction = CGFloat.random(in: 0.55...0.70, using: &generator)
        let center = CGPoint(x: foldX, y: (height * centerFraction).rounded())
        blobCenter = center

        // Crease: a vertical polyline with sub-point wobble every 40 pt, full height or down to the blob.
        let creaseEnd = spec.creaseExtent == .full ? height : center.y
        var crease: [CGPoint] = []
        var y: CGFloat = 0
        while y < creaseEnd {
            crease.append(CGPoint(x: foldX + CGFloat.random(in: -0.6...0.6, using: &generator), y: y))
            y += 40
        }
        crease.append(CGPoint(x: foldX, y: creaseEnd))
        creasePoints = crease
        let radiusY = CGFloat.random(in: 20...35, using: &generator) * spec.blobScale
        let radiusX = CGFloat.random(in: 4...8, using: &generator) * spec.blobScale
        let pointCount = Int.random(in: 14...20, using: &generator)
        var blob: [CGPoint] = []
        if spec.blobScale > 0 {
            blob.reserveCapacity(pointCount)
            for index in 0..<pointCount {
                let angle = (CGFloat(index) / CGFloat(pointCount)) * .pi * 2
                let jitterX = CGFloat.random(in: 0.5...1.5, using: &generator)
                let jitterY = CGFloat.random(in: 0.85...1.15, using: &generator)
                blob.append(CGPoint(
                    x: center.x + cos(angle) * radiusX * jitterX,
                    y: center.y + sin(angle) * radiusY * jitterY
                ))
            }
        }
        blobPoints = blob
        blobBottom = blob.map(\.y).max() ?? center.y

        // Horizontal stuck lines: a stack centred a little off the blob, out to the right edge.
        let count = max(0, spec.horizontalLineCount)
        let thickness = spec.horizontalLineThickness
        let spacing = spec.horizontalLineSpacing
        let stackHeight = CGFloat(count) * thickness + CGFloat(max(0, count - 1)) * spacing
        let stackTop = center.y - stackHeight / 2 + CGFloat.random(in: -6...6, using: &generator)
        var lines: [CGRect] = []
        for index in 0..<count {
            let lineY = stackTop + CGFloat(index) * (thickness + spacing)
            lines.append(CGRect(x: center.x, y: lineY, width: width - center.x, height: thickness))
        }
        horizontalLines = lines

        // Vertical stuck line: from the bottom of the blob to the bottom edge.
        if spec.verticalLineColor != nil {
            let lineWidth = spec.verticalLineWidth
            let top = blobBottom - 2
            verticalLine = CGRect(x: center.x - lineWidth / 2, y: top, width: lineWidth, height: max(0, height - top))
        } else {
            verticalLine = nil
        }

        // Lone dead pixels scattered along the crease.
        var pixels: [CGRect] = []
        for _ in 0..<max(0, spec.deadPixelCount) {
            let pixelY = CGFloat.random(in: (height * 0.1)...(height * 0.9), using: &generator)
            let offset = CGFloat.random(in: -2...2, using: &generator)
            let length = 1.5 + CGFloat.random(in: 0...6, using: &generator)
            pixels.append(CGRect(x: foldX - 0.75 + offset, y: pixelY, width: 1.5, height: length))
        }
        deadPixels = pixels
    }

    /// Maps canonical space onto the view. Identity for a vertical fold. For a horizontal fold it is a
    /// quarter turn (a rotation, never a mirror): canonical right becomes up, canonical down becomes
    /// right. On iPhone Duo that puts the stuck row to the right and the line down when the phone
    /// is held open the usual way.
    public var transform: CGAffineTransform {
        switch fold.axis {
        case .vertical: .identity
        case .horizontal: CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: canonicalSize.width)
        }
    }

    public var creasePath: Path {
        var path = Path()
        guard let first = creasePoints.first else { return path }
        path.move(to: first)
        for point in creasePoints.dropFirst() {
            path.addLine(to: point)
        }
        return path.applying(transform)
    }

    public var blobPath: Path? {
        guard blobPoints.count > 2 else { return nil }
        var path = Path()
        path.move(to: blobPoints[0])
        for point in blobPoints.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path.applying(transform)
    }

    /// Horizontal lines clipped to `progress` (0…1) of their full length, in canonical space.
    public func horizontalLineRects(progress: Double) -> [CGRect] {
        let fraction = CGFloat(min(max(progress, 0), 1))
        return horizontalLines.map { rect in
            CGRect(x: rect.minX, y: rect.minY, width: rect.width * fraction, height: rect.height)
        }
    }

    /// The half of the panel beyond the fold, in canonical space.
    public var trailingPanel: CGRect {
        CGRect(x: foldPosition, y: 0, width: max(0, canonicalSize.width - foldPosition), height: canonicalSize.height)
    }

    /// The stuck rows stretched across the whole width, for the moment the panel re-initialises.
    public var glitchLineRects: [CGRect] {
        horizontalLines.map { CGRect(x: 0, y: $0.minY, width: canonicalSize.width, height: $0.height) }
    }

    /// The vertical line clipped to `progress` (0…1) of its full length, in canonical space.
    public func verticalLineRect(progress: Double) -> CGRect? {
        guard let verticalLine else { return nil }
        let fraction = CGFloat(min(max(progress, 0), 1))
        return CGRect(x: verticalLine.minX, y: verticalLine.minY, width: verticalLine.width, height: verticalLine.height * fraction)
    }
}
