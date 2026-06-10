import Charts
import SwiftUI

/// Small floating card shown at the hovered point on a chart.
struct ChartTooltip: View {
    struct Row: Identifiable {
        let label: String
        let color: Color
        let value: String
        var id: String { label }
    }

    let rows: [Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(rows) { row in
                HStack(spacing: 6) {
                    Circle()
                        .fill(row.color)
                        .frame(width: 7, height: 7)
                    Text(row.label)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 12)
                    Text(row.value)
                        .monospacedDigit()
                }
            }
        }
        .font(.caption)
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
        .fixedSize()
    }
}

extension View {
    /// Tracks the pointer over a chart's plot area and reports the nearest
    /// integer x index (or nil when the pointer leaves).
    func chartXHover(capacity: Int, selection: Binding<Int?>) -> some View {
        chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            guard let anchor = proxy.plotFrame else { return }
                            let plot = geometry[anchor]
                            let x = location.x - plot.minX
                            guard x >= 0, x <= plot.width, let index: Int = proxy.value(atX: x) else {
                                selection.wrappedValue = nil
                                return
                            }
                            selection.wrappedValue = min(max(index, 0), capacity - 1)
                        case .ended:
                            selection.wrappedValue = nil
                        }
                    }
            }
        }
    }
}
