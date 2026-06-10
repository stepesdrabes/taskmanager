import SwiftUI

/// Stacked horizontal breakdown bar with a legend — Activity Monitor style.
struct CompositionBar: View {
    struct Segment: Identifiable {
        let label: String
        let value: UInt64
        let color: Color
        var id: String { label }
    }

    let segments: [Segment]
    let total: UInt64

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geometry in
                HStack(spacing: 1) {
                    ForEach(segments) { segment in
                        Rectangle()
                            .fill(segment.color.gradient)
                            .frame(width: geometry.size.width * CGFloat(segment.value) / CGFloat(max(total, 1)))
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 14)
            .background(.quaternary.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 4))

            HStack(spacing: 16) {
                ForEach(segments) { segment in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(segment.color)
                            .frame(width: 7, height: 7)
                        Text("\(segment.label) \(Format.bytes(segment.value))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }
}
