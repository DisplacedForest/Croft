import Design
import Domain
import GardenModel
import SwiftUI

struct BedCardView<MenuItems: View>: View {
    let summary: BedSummary
    let open: () -> Void
    @ViewBuilder let menu: () -> MenuItems

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: CroftTheme.space(2)) {
                HStack(alignment: .firstTextBaseline, spacing: CroftTheme.space(2)) {
                    Image(systemName: summary.bed.kind.symbolName)
                        .foregroundStyle(.tint)
                        .font(.system(.body, weight: .light))
                    Text(summary.bed.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                Text(summary.plantNamesLine ?? "Nothing growing yet")
                    .font(CroftTheme.supporting)
                    .foregroundStyle(summary.plantNamesLine == nil ? .tertiary : .primary)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                Text(metaLine ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(CroftTheme.space(4))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .contextMenu {
            menu()
        }
    }

    private var metaLine: String? {
        let parts = [summary.statusLine, summary.latestActivity?.phrase].compactMap { $0 }
        guard !parts.isEmpty else {
            return nil
        }
        return parts.joined(separator: " · ")
    }
}
