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

    var tagline: String {
        switch self {
        case .today: "Your day at a glance."
        case .garden: "Where your garden takes root."
        case .plants: "A field guide to what you grow."
        }
    }

    var summary: String {
        switch self {
        case .today: "Date, weather, and what the garden needs now."
        case .garden: "Beds, plantings, observations, and harvests will live here."
        case .plants: "Species, cultivars, growing conditions, and threats will live here."
        }
    }
}
