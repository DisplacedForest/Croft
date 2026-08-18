import SwiftUI

struct SectionDetailView: View {
    let route: SectionRoute
    let navigate: (SectionRoute) -> Void

    var body: some View {
        switch route {
        case .season:
            SeasonView()
        case .bed(let bedID):
            BedDetailView(bedID: bedID, navigate: navigate)
        case .planting(let plantingID):
            PlantingDetailView(plantingID: plantingID)
        case .plant(let identity):
            PlantPageView(identity: identity)
        }
    }
}
