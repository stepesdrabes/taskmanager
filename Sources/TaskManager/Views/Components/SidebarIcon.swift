import SwiftUI

/// White symbol on a small colored rounded rectangle — the System Settings sidebar look.
struct SidebarIcon: View {
    let section: MonitorSection

    var body: some View {
        Image(systemName: section.symbol)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(section.tint.gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
