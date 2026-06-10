import SwiftUI

/// System-Settings-style segmented capacity bar: a title, a "used of total"
/// caption, a stacked meter whose segments show a tooltip on hover, and a legend.
struct StorageMeter: View {
    struct Slice: Identifiable {
        let label: String
        let bytes: UInt64
        let color: Color
        var id: String { label }
    }

    let title: String
    let caption: String
    let used: [Slice]      // the breakdown of the used portion
    let free: UInt64
    let total: UInt64
    let freeLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.callout.weight(.medium))
                Spacer()
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            GeometryReader { geometry in
                HStack(spacing: 1) {
                    ForEach(used) { slice in
                        slice.color
                            .frame(width: width(slice.bytes, in: geometry.size.width))
                            .help("\(slice.label): \(Format.storageBytes(slice.bytes))")
                    }
                    Rectangle()
                        .fill(.quaternary)
                        .help("\(freeLabel): \(Format.storageBytes(free))")
                }
            }
            .frame(height: 16)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            if used.count > 1 {
                legend
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach(used) { slice in
                HStack(spacing: 5) {
                    Circle()
                        .fill(slice.color)
                        .frame(width: 7, height: 7)
                    Text(slice.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func width(_ bytes: UInt64, in fullWidth: CGFloat) -> CGFloat {
        guard total > 0 else { return 0 }
        return fullWidth * CGFloat(bytes) / CGFloat(total)
    }
}
