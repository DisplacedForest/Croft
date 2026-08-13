import Domain
import Foundation
import GardenModel

extension BedKind {
    var displayName: String {
        switch self {
        case .raised: "Raised bed"
        case .inGround: "In-ground bed"
        case .container: "Container"
        }
    }

    var symbolName: String {
        switch self {
        case .raised: "square.stack.3d.up"
        case .inGround: "leaf"
        case .container: "basket"
        }
    }
}

extension PlantingStatus {
    var displayName: String {
        switch self {
        case .planned: "Planned"
        case .active: "Growing"
        case .finished: "Finished"
        case .failed: "Failed"
        }
    }
}

extension PlantingActivityKind {
    var displayName: String {
        switch self {
        case .planted: "Planted"
        case .transplanted: "Transplanted"
        case .finished: "Finished"
        case .failed: "Failed"
        }
    }
}

extension BedSummary {
    var plantNamesLine: String? {
        let names = plantings.map(\.plantName)
        guard !names.isEmpty else {
            return nil
        }
        var unique: [String] = []
        for name in names where !unique.contains(name) {
            unique.append(name)
        }
        return unique.joined(separator: ", ")
    }

    var statusLine: String? {
        let growing = plantings.count { $0.planting.status == .active }
        let planned = plantings.count { $0.planting.status == .planned }
        var parts: [String] = []
        if growing > 0 {
            parts.append("\(growing) growing")
        }
        if planned > 0 {
            parts.append("\(planned) planned")
        }
        guard !parts.isEmpty else {
            return nil
        }
        return parts.joined(separator: " · ")
    }
}

extension PlantingActivity {
    var phrase: String {
        "\(kind.displayName) \(plantName), \(date.gardenDisplay)"
    }
}

extension Date {
    var gardenDisplay: String {
        formatted(date: .abbreviated, time: .omitted)
    }
}
