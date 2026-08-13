import Design
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case today
    case garden
    case plants

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .today: "Today"
        case .garden: "Garden"
        case .plants: "Plants"
        }
    }

    var symbolName: String {
        switch self {
        case .today: "sun.horizon"
        case .garden: "tree"
        case .plants: "leaf"
        }
    }

    var domainColor: Color {
        switch self {
        case .today: .domainWater
        case .garden: .domainGarden
        case .plants: .domainGarden
        }
    }

}
