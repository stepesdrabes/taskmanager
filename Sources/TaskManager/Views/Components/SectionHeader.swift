import SwiftUI

/// Big section title on the left, hardware name on the right.
struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.largeTitle.weight(.semibold))
            Spacer()
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}
