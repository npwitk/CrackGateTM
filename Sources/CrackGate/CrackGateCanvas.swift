import SwiftUI

/// Draws one broken unit. Pure function of its inputs; no state.
struct CrackGateCanvas: View {
    let geometry: DefectGeometry
    let spec: CrackGateStyle.Spec
    /// 0…1, how far the stuck lines have spread from the blob.
    let progress: Double
    /// Stretch the stuck rows across the whole width for the re-initialising flash.
    let glitching: Bool
    /// 0…1 opacity multiplier on the stuck lines for the flicker effect.
    let flicker: Double
    /// 0…1, how far the half beyond the fold is dimmed right now.
    let panelDim: Double
    let colorScheme: ColorScheme
    /// Device space → window. Identity when the interface is in portrait.
    var windowTransform: CGAffineTransform = .identity

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, _ in
            let transform = geometry.transform.concatenating(windowTransform)
            let horizontalRects = glitching ? geometry.glitchLineRects : geometry.horizontalLineRects(progress: progress)
            let horizontal = horizontalRects.map { Path($0).applying(transform) }
            let vertical = geometry.verticalLineRect(progress: progress).map { Path($0).applying(transform) }
            let hasLines = !horizontal.isEmpty || vertical != nil

            // The far half browning out. Under the stuck pixels, which stay lit.
            if panelDim > 0 {
                context.fill(Path(geometry.trailingPanel).applying(transform), with: .color(.black.opacity(panelDim)))
            }

            // Bloom behind the stuck pixels.
            if hasLines, spec.glowRadius > 0 {
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: spec.glowRadius))
                    layer.opacity = 0.9 * flicker
                    fillLines(horizontal: horizontal, vertical: vertical, in: &layer)
                }
            }

            // The stuck pixels themselves.
            if hasLines {
                context.drawLayer { layer in
                    layer.opacity = flicker
                    fillLines(horizontal: horizontal, vertical: vertical, in: &layer)
                }
            }

            // The crease.
            let creaseBase = spec.creaseColor ?? (colorScheme == .dark ? Color.white : Color.black)
            context.stroke(
                geometry.creasePath.applying(windowTransform),
                with: .color(creaseBase.opacity(spec.creaseOpacity)),
                style: StrokeStyle(lineWidth: spec.creaseWidth, lineCap: .round, lineJoin: .round)
            )

            // Dead pixels are simply off.
            if let blob = geometry.blobPath {
                context.fill(blob.applying(windowTransform), with: .color(.black))
            }
            for pixel in geometry.deadPixels {
                context.fill(Path(pixel).applying(transform), with: .color(.black))
            }
        }
    }

    private func fillLines(horizontal: [Path], vertical: Path?, in layer: inout GraphicsContext) {
        for (index, path) in horizontal.enumerated() {
            layer.fill(path, with: horizontalShading(index: index, bounds: path.boundingRect))
        }
        if let vertical, let color = spec.verticalLineColor {
            if let border = spec.verticalLineBorderColor {
                layer.stroke(vertical, with: .color(border), lineWidth: 1.2)
            }
            layer.fill(vertical, with: .color(color))
        }
    }

    private func horizontalShading(index: Int, bounds: CGRect) -> GraphicsContext.Shading {
        let colors = spec.horizontalLineColors
        guard !colors.isEmpty else { return .color(.clear) }
        if spec.horizontalLineGradient, colors.count > 1 {
            // Run the gradient along the line's long side, whichever way it ends up on screen.
            let start: CGPoint
            let end: CGPoint
            if bounds.width >= bounds.height {
                start = CGPoint(x: bounds.minX, y: bounds.midY)
                end = CGPoint(x: bounds.maxX, y: bounds.midY)
            } else {
                start = CGPoint(x: bounds.midX, y: bounds.minY)
                end = CGPoint(x: bounds.midX, y: bounds.maxY)
            }
            return .linearGradient(Gradient(colors: colors), startPoint: start, endPoint: end)
        }
        return .color(colors[index % colors.count])
    }
}
