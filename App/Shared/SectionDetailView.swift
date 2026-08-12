import SwiftUI

struct SectionDetailView: View {
    let route: SectionRoute

    var body: some View {
        switch route {
        case .navigationPreview(let section):
            VStack(spacing: CroftTheme.space(3)) {
                Text("Detail screens open here.")
                    .font(CroftTheme.heading)
                Text("\(section.title) screens will push into this space.")
                    .font(CroftTheme.supporting)
                    .foregroundStyle(.secondary)
            }
            .padding(CroftTheme.space(8))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Preview")
        }
    }
}
