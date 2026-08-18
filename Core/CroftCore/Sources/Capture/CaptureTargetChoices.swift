import Foundation
import Persistence

import struct Domain.Bed
import struct Domain.Cultivar
import struct Domain.Garden
import enum Domain.ObservationTarget
import enum Domain.PlantIdentity
import struct Domain.Planting
import struct Domain.Species

public struct CaptureTargetChoice: Identifiable, Hashable, Sendable {
    public let target: ObservationTarget
    public let label: String

    public var id: ObservationTarget { target }

    public init(target: ObservationTarget, label: String) {
        self.target = target
        self.label = label
    }
}

public struct CapturePlantingChoice: Identifiable, Hashable, Sendable {
    public let plantingID: Planting.ID
    public let label: String

    public var id: Planting.ID { plantingID }

    public init(plantingID: Planting.ID, label: String) {
        self.plantingID = plantingID
        self.label = label
    }
}

public struct CaptureTargetChoices: Sendable {
    public let plantings: [CaptureTargetChoice]
    public let beds: [CaptureTargetChoice]
    public let gardens: [CaptureTargetChoice]

    public var isEmpty: Bool {
        plantings.isEmpty && beds.isEmpty && gardens.isEmpty
    }
}

extension CaptureContext {
    public func targetChoices() throws -> CaptureTargetChoices {
        let bedEntries = try activeBeds()
        let beds = bedEntries.map { entry in
            CaptureTargetChoice(
                target: .bed(entry.bed.id),
                label: "\(entry.bed.name) · \(entry.gardenName)"
            )
        }
        var gardens: [CaptureTargetChoice] = []
        for property in try structures.properties() {
            for garden in try structures.gardens(in: property.id) {
                gardens.append(CaptureTargetChoice(target: .garden(garden.id), label: garden.name))
            }
        }
        let plantings = try plantingChoices().map { choice in
            CaptureTargetChoice(target: .planting(choice.plantingID), label: choice.label)
        }
        return CaptureTargetChoices(plantings: plantings, beds: beds, gardens: gardens)
    }

    public func plantingChoices() throws -> [CapturePlantingChoice] {
        let names = try PlantingNameIndex(personal)
        let bedNames = Dictionary(
            uniqueKeysWithValues: try activeBeds().map { ($0.bed.id, $0.bed.name) }
        )
        return try plantings.fetchAll()
            .map { planting in
                let plant = names.name(for: planting.identity)
                let bed = bedNames[planting.bedID]
                return CapturePlantingChoice(
                    plantingID: planting.id,
                    label: bed.map { "\(plant) · \($0)" } ?? plant
                )
            }
            .sorted { $0.label < $1.label }
    }

    public func targetLabel(for target: ObservationTarget) throws -> String? {
        switch target {
        case .plant(let identity):
            return try PlantingNameIndex(personal).name(for: identity)
        case .planting, .bed, .garden:
            let choices = try targetChoices()
            return (choices.plantings + choices.beds + choices.gardens)
                .first { $0.target == target }?
                .label
        }
    }
}

struct PlantingNameIndex {
    private let cultivarNames: [Cultivar.ID: String]
    private let speciesNames: [Species.ID: String]

    init(_ database: AppDatabase) throws {
        speciesNames = Dictionary(
            uniqueKeysWithValues: try SpeciesRepository(database).fetchAll().map {
                ($0.id, $0.commonNames.first ?? $0.scientificName)
            }
        )
        cultivarNames = Dictionary(
            uniqueKeysWithValues: try CultivarRepository(database).fetchAll().map {
                ($0.id, $0.name)
            }
        )
    }

    func name(for identity: PlantIdentity) -> String {
        switch identity {
        case .cultivar(let id):
            cultivarNames[id] ?? "Unknown plant"
        case .species(let id):
            speciesNames[id] ?? "Unknown plant"
        }
    }
}
