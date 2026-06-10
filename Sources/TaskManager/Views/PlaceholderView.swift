import SwiftUI

/// Stand-in detail view until each section's real view lands.
struct PlaceholderView: View {
    let section: MonitorSection

    var body: some View {
        ContentUnavailableView {
            Label(section.title, systemImage: section.symbol)
        } description: {
            Text("This section arrives in a later build step.")
        }
    }
}
