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
                HStack(spacing: CroftTheme.space(2)) {
                    if let status = summary.statusLine {
                        Text(status)
                    }
                    if summary.statusLine != nil, summary.latestActivity != nil {
                        Text("·")
                    }
                    if let activity = summary.latestActivity {
                        Text(activity.phrase)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(CroftTheme.space(4))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .contextMenu {
            menu()
        }
    }
}
