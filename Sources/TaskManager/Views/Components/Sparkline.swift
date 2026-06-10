import SwiftUI

/// Canvas-drawn mini chart for per-core grids — far lighter than a Chart view.
struct Sparkline: View {
    let values: [Double]   // 0...1, oldest first
    let capacity: Int
    var tint: Color = .blue

    var body: some View {
        Canvas { context, size in
            guard values.count > 1, capacity > 1 else { return }
            let stepX = size.width / CGFloat(capacity - 1)
            let startX = CGFloat(capacity - values.count) * stepX
            func point(_ index: Int) -> CGPoint {
                CGPoint(
                    x: startX + CGFloat(index) * stepX,
                    y: size.height * (1 - CGFloat(min(max(values[index], 0), 1)))
                )
            }

            var line = Path()
            line.move(to: point(0))
            for index in 1..<values.count {
                line.addLine(to: point(index))
            }

            var fill = line
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: startX, y: size.height))
            fill.closeSubpath()

            context.fill(
                fill,
                with: .linearGradient(
                    Gradient(colors: [tint.opacity(0.35), tint.opacity(0.03)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
            context.stroke(line, with: .color(tint), lineWidth: 1)
        }
    }
}
