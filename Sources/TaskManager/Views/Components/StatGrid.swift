import SwiftUI

/// Windows-Task-Manager-style stat block: small grey label, larger value below.
struct StatGrid: View {
    struct Item: Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    let items: [Item]
    var valueFont: Font = .title3

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), alignment: .topLeading)],
            alignment: .leading,
            spacing: 16
        ) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.value)
                        .font(valueFont)
                        .monospacedDigit()
                }
            }
        }
    }
}
