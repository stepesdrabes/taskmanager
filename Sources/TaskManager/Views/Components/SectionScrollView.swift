import SwiftUI

/// Scrolling container for a section: shows the big in-content title, and surfaces
/// the same title in the toolbar only once the header has scrolled away — so there
/// are never two visible titles at once.
struct SectionScrollView<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    @State private var scrolledPastHeader = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: title, subtitle: subtitle)
                content
            }
            .padding(24)
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y > 44
        } action: { _, pastHeader in
            if pastHeader != scrolledPastHeader {
                scrolledPastHeader = pastHeader
            }
        }
        // Same leading toolbar title as before, but only once the big header
        // has scrolled away — so the two are never visible at once.
        .navigationTitle(scrolledPastHeader ? title : "")
    }
}
