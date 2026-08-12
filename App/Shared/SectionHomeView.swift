import SwiftUI

struct SectionHomeView: View {
    let section: AppSection
    let navigate: (SectionRoute) -> Void

    var body: some View {
        VStack(spacing: CroftTheme.space(4)) {
            Image(systemName: section.symbolName)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tint)
                .padding(CroftTheme.space(6))
                .background(.tint.opacity(0.12), in: Circle())
            Text(section.tagline)
                .font(CroftTheme.heading)
                .multilineTextAlignment(.center)
            Text(section.summary)
                .font(CroftTheme.supporting)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            Button("Preview a detail screen") {
                navigate(.navigationPreview(section))
            }
            .buttonStyle(.bordered)
            .padding(.top, CroftTheme.space(4))
        }
        .padding(CroftTheme.space(8))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
