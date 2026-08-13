import SwiftUI

struct SectionHomeView: View {
    let section: AppSection
    let navigate: (SectionRoute) -> Void

    var body: some View {
        switch section {
        case .today:
            TodayView()
        case .garden:
            GardenHomeView(navigate: navigate)
        case .plants:
            PlantsHomeView(navigate: navigate)
        }
    }
}
