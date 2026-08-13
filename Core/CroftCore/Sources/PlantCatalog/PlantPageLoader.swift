import Domain
import Foundation
import GRDB
import Graph
import Persistence

public struct PlantPageLoader: Sendable {
    private let knowledge: AppDatabase
    private let species: SpeciesRepository
    private let cultivars: CultivarRepository
    private let genera: GenusRepository
    private let families: PlantFamilyRepository
    private let pests: PestRepository
    private let diseases: DiseaseRepository
    private let plantings: PlantingRepository
    private let structures: GardenStructureRepository

    public init(knowledge: AppDatabase, personal: AppDatabase) {
        self.knowledge = knowledge
        species = SpeciesRepository(knowledge)
        cultivars = CultivarRepository(knowledge)
        genera = GenusRepository(knowledge)
        families = PlantFamilyRepository(knowledge)
        pests = PestRepository(knowledge)
        diseases = DiseaseRepository(knowledge)
        plantings = PlantingRepository(personal)
        structures = GardenStructureRepository(personal)
    }

    public init(_ database: AppDatabase) {
        self.init(knowledge: database, personal: database)
    }

    public func listItems() throws -> [PlantListItem] {
        let allSpecies = try species.fetchAll()
        let allCultivars = try cultivars.fetchAll()
        let speciesByID = Dictionary(uniqueKeysWithValues: allSpecies.map { ($0.id, $0) })
        var items = allSpecies.map { one in
            PlantListItem(
                id: one.id.rawValue,
                identity: .species(one.id),
                kind: .species,
                displayName: titled(one.commonNames.first) ?? one.scientificName,
                scientificName: one.scientificName,
                otherNames: Array(one.commonNames.dropFirst())
            )
        }
        items += allCultivars.map { cultivar in
            let parent = speciesByID[cultivar.speciesID]
            var otherNames = cultivar.commonNames
            if let parentName = parent?.commonNames.first {
                otherNames.append(parentName)
            }
            return PlantListItem(
                id: cultivar.id.rawValue,
                identity: .cultivar(cultivar.id),
                kind: .cultivar,
                displayName: cultivar.name,
                scientificName: cultivarScientificName(cultivar, parent),
                otherNames: otherNames
            )
        }
        return items.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    public func page(for identity: PlantIdentity) throws -> PlantPage? {
        switch identity {
        case .species(let id):
            guard let one = try species.fetch(id: id) else { return nil }
            return try assemble(species: one, cultivar: nil)
        case .cultivar(let id):
            guard let cultivar = try cultivars.fetch(id: id),
                let parent = try species.fetch(id: cultivar.speciesID)
            else { return nil }
            return try assemble(species: parent, cultivar: cultivar)
        }
    }

    private func assemble(species one: Species, cultivar: Cultivar?) throws -> PlantPage {
        let genus = try genera.fetch(id: one.genusID)
        let family = try genus.flatMap { try families.fetch(id: $0.familyID) }
        let identity: PlantIdentity =
            if let cultivar {
                .cultivar(cultivar.id)
            } else {
                .species(one.id)
            }

        var threatIDs = [one.id.rawValue]
        if let cultivar {
            threatIDs.insert(cultivar.id.rawValue, at: 0)
        }
        let threats = try threats(fromPlantIDs: threatIDs)

        let relevantPlantings = try relevantPlantings(species: one, cultivar: cultivar)
        var locationNames: [Bed.ID: String] = [:]
        for planting in relevantPlantings where locationNames[planting.bedID] == nil {
            locationNames[planting.bedID] = try locationName(ofBed: planting.bedID)
        }

        return PlantPage(
            identity: identity,
            displayName: cultivar?.name ?? titled(one.commonNames.first) ?? one.scientificName,
            commonNames: cultivar?.commonNames ?? one.commonNames,
            taxonomy: PlantTaxonomy(
                familyName: family?.name,
                genusName: genus?.name,
                scientificName: one.scientificName,
                cultivarName: cultivar?.name
            ),
            conditions: GrowingConditions.merged(species: one, cultivar: cultivar),
            threats: threats,
            currentPlantings: currentPlantings(
                from: relevantPlantings, locationNames: locationNames),
            activity: activity(from: relevantPlantings, locationNames: locationNames)
        )
    }

    private func relevantPlantings(species one: Species, cultivar: Cultivar?) throws -> [Planting] {
        if let cultivar {
            return try plantings.plantings(of: .cultivar(cultivar.id))
        }
        var found = try plantings.plantings(of: .species(one.id))
        for child in try cultivars.cultivars(ofSpecies: one.id) {
            found += try plantings.plantings(of: .cultivar(child.id))
        }
        return found
    }

    private func currentPlantings(
        from relevantPlantings: [Planting],
        locationNames: [Bed.ID: String]
    ) -> [CurrentPlanting] {
        relevantPlantings
            .filter { $0.status == .planned || $0.status == .active }
            .map { planting in
                CurrentPlanting(
                    id: planting.id.rawValue,
                    locationName: locationNames[planting.bedID],
                    quantity: planting.quantity,
                    status: planting.status,
                    plantedOn: planting.plantedOn,
                    expectedMaturityOn: planting.expectedMaturityOn
                )
            }
    }

    private func threats(fromPlantIDs plantIDs: [String]) throws -> [PlantThreat] {
        let edges = try knowledge.writer.read { db in
            try plantIDs.flatMap { plantID in
                try GraphStore.outgoing(from: plantID, via: .hostOf, in: db)
                    + GraphStore.outgoing(from: plantID, via: .susceptibleTo, in: db)
            }
        }
        var seen = Set<String>()
        var threats: [PlantThreat] = []
        for edge in edges where !seen.contains(edge.target.id) {
            seen.insert(edge.target.id)
            switch edge.target.type {
            case .pest:
                guard let pest = try pests.fetch(id: Pest.ID(rawValue: edge.target.id)),
                    pest.organismType == .pest
                else { continue }
                threats.append(
                    PlantThreat(
                        id: pest.id.rawValue,
                        kind: .pest,
                        name: pest.commonName,
                        agentName: pest.scientificName,
                        summary: pest.typicalDamage ?? pest.description,
                        affectedParts: pest.affectedPlantParts
                    ))
            case .disease:
                guard let disease = try diseases.fetch(id: Disease.ID(rawValue: edge.target.id))
                else { continue }
                threats.append(
                    PlantThreat(
                        id: disease.id.rawValue,
                        kind: .disease,
                        name: disease.name,
                        agentName: disease.pathogen,
                        summary: disease.symptoms,
                        affectedParts: disease.affectedPlantParts
                    ))
            default:
                continue
            }
        }
        return threats.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func activity(
        from relevantPlantings: [Planting],
        locationNames: [Bed.ID: String]
    ) -> [ActivityEvent] {
        var events: [ActivityEvent] = []
        for planting in relevantPlantings {
            let location = locationNames[planting.bedID]
            if let plantedOn = planting.plantedOn {
                events.append(
                    ActivityEvent(
                        id: "\(planting.id.rawValue)-planted",
                        date: plantedOn,
                        kind: .planted,
                        locationName: location,
                        quantity: planting.quantity
                    ))
            }
            if let transplantedOn = planting.transplantedOn {
                events.append(
                    ActivityEvent(
                        id: "\(planting.id.rawValue)-transplanted",
                        date: transplantedOn,
                        kind: .transplanted,
                        locationName: location,
                        quantity: planting.quantity
                    ))
            }
            let ended = planting.status == .finished || planting.status == .failed
            if let endedOn = planting.endedOn, ended {
                events.append(
                    ActivityEvent(
                        id: "\(planting.id.rawValue)-ended",
                        date: endedOn,
                        kind: planting.status == .failed ? .failed : .finished,
                        locationName: location,
                        quantity: planting.quantity
                    ))
            }
        }
        return Array(events.sorted { $0.date > $1.date }.prefix(20))
    }

    private func locationName(ofBed bedID: Bed.ID) throws -> String? {
        guard let bed = try structures.bed(id: bedID) else { return nil }
        let parentName: String? =
            switch try structures.parent(ofBed: bedID) {
            case .garden(let id): try structures.garden(id: id)?.name
            case .growingArea(let id): try structures.growingArea(id: id)?.name
            case nil: nil
            }
        guard let parentName else { return bed.name }
        return "\(bed.name), \(parentName)"
    }

    private func cultivarScientificName(_ cultivar: Cultivar, _ parent: Species?) -> String {
        guard let parent else { return cultivar.name }
        return "\(parent.scientificName) '\(cultivar.name)'"
    }

    private func titled(_ name: String?) -> String? {
        guard let name, let first = name.first else { return name }
        return first.uppercased() + name.dropFirst()
    }
}
