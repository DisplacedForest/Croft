import SwiftUI

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case garden
    case plants

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .garden: "Garden"
        case .plants: "Plants"
        }
    }

    var symbolName: String {
        switch self {
        case .garden: "tree"
        case .plants: "leaf"
        }
    }

    var tagline: String {
        switch self {
        case .garden: "Where your garden takes root."
        case .plants: "A field guide to what you grow."
        }
    }

    var summary: String {
        switch self {
        case .garden: "Beds, plantings, observations, and harvests will live here."
        case .plants: "Species, cultivars, growing conditions, and threats will live here."
        }
    }
}
