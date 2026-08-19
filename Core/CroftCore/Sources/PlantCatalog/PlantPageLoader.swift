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
    private let plantings: PlantingRepository
    private let structures: GardenStructureRepository
    private let images: PlantImageStore
    private let threatResolver: PlantThreatResolver
    private let locale: Locale

    public init(knowledge: AppDatabase, personal: AppDatabase, locale: Locale = .current) {
        self.knowledge = knowledge
        species = SpeciesRepository(knowledge)
        cultivars = CultivarRepository(knowledge)
        genera = GenusRepository(knowledge)
        families = PlantFamilyRepository(knowledge)
        plantings = PlantingRepository(personal)
        structures = GardenStructureRepository(personal)
        images = PlantImageStore(knowledge)
        threatResolver = PlantThreatResolver(knowledge: knowledge)
        self.locale = locale
    }

    public init(_ database: AppDatabase, locale: Locale = .current) {
        self.init(knowledge: database, personal: database, locale: locale)
    }

    public func listItems() throws -> [PlantListItem] {
        let allSpecies = try species.fetchAll()
        let allCultivars = try cultivars.fetchAll()
        let speciesByID = Dictionary(uniqueKeysWithValues: allSpecies.map { ($0.id, $0) })
        let imagesByOwner = try images.imagesByOwner()
        var items = allSpecies.map { one in
            speciesItem(one, imagesByOwner: imagesByOwner)
        }
        items += allCultivars.map { cultivar in
            let parent = speciesByID[cultivar.speciesID]
            var otherNames = cultivar.commonNames
            if let parentName = parent?.commonNames.first {
                otherNames.append(parentName)
            }
            let bareName = VarietalName.bare(
                cultivar.name, cropNames: parent?.allCommonNames ?? [])
            return PlantListItem(
                id: cultivar.id.rawValue,
                identity: .cultivar(cultivar.id),
                kind: .cultivar,
                displayName: cultivar.name,
                scientificName: cultivarScientificName(quoting: bareName, parent: parent),
                otherNames: otherNames,
                imageFile: (imagesByOwner[cultivar.id.rawValue]
                    ?? imagesByOwner[cultivar.speciesID.rawValue])?.file
            )
        }
        return items.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private func speciesItem(
        _ one: Species,
        imagesByOwner: [String: PlantImage]
    ) -> PlantListItem {
        let preferred = one.preferredCommonName(for: locale)
        let others = one.allCommonNames.filter { $0 != preferred }
        return PlantListItem(
            id: one.id.rawValue,
            identity: .species(one.id),
            kind: .species,
            displayName: titled(preferred) ?? one.scientificName,
            scientificName: one.scientificName,
            otherNames: others,
            imageFile: imagesByOwner[one.id.rawValue]?.file
        )
    }

    public func cropCatalog() throws -> CropCatalog {
        let allSpecies = try species.fetchAll()
        let allCultivars = try cultivars.fetchAll()
        let speciesByID = Dictionary(uniqueKeysWithValues: allSpecies.map { ($0.id, $0) })
        let imagesByOwner = try images.imagesByOwner()
        let cultivarsBySpecies = Dictionary(grouping: allCultivars, by: \.speciesID)
        let groups = allSpecies.map { one in
            let crop = speciesItem(one, imagesByOwner: imagesByOwner)
            let siblings = cultivarsBySpecies[one.id] ?? []
            let bareNames = Dictionary(
                siblings.map { sibling -> (String, Int) in
                    let candidate = VarietalName.bare(
                        sibling.name, cropNames: one.allCommonNames)
                    return (VarietalName.collisionKey(candidate), 1)
                },
                uniquingKeysWith: { $0 + $1 }
            )
            let varietals =
                siblings
                .map { cultivar -> PlantListItem in
                    let candidate = VarietalName.bare(
                        cultivar.name, cropNames: one.allCommonNames)
                    let collides = (bareNames[VarietalName.collisionKey(candidate)] ?? 0) > 1
                    let bareName = collides ? cultivar.name : candidate
                    var otherNames = cultivar.commonNames
                    if bareName != cultivar.name {
                        otherNames.append(cultivar.name)
                    }
                    return PlantListItem(
                        id: cultivar.id.rawValue,
                        identity: .cultivar(cultivar.id),
                        kind: .cultivar,
                        displayName: bareName,
                        scientificName: cultivarScientificName(
                            quoting: bareName, parent: speciesByID[cultivar.speciesID]),
                        otherNames: otherNames,
                        imageFile: (imagesByOwner[cultivar.id.rawValue]
                            ?? imagesByOwner[cultivar.speciesID.rawValue])?.file
                    )
                }
                .sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName)
                        == .orderedAscending
                }
            return CropGroup(crop: crop, varietals: varietals)
        }
        return CropCatalog(
            crops: groups.sorted {
                $0.crop.displayName.localizedCaseInsensitiveCompare($1.crop.displayName)
                    == .orderedAscending
            })
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
        let threats = try threatResolver.threats(
            fromPlantIDs: threatIDs, hostID: one.id.rawValue)

        let relevantPlantings = try relevantPlantings(species: one, cultivar: cultivar)
        var locationNames: [Bed.ID: String] = [:]
        for planting in relevantPlantings where locationNames[planting.bedID] == nil {
            locationNames[planting.bedID] = try locationName(ofBed: planting.bedID)
        }

        let bareCultivarName = try cultivar.map { current in
            let candidate = VarietalName.bare(current.name, cropNames: one.allCommonNames)
            let candidateKey = VarietalName.collisionKey(candidate)
            let collides = try cultivars.cultivars(ofSpecies: one.id).contains { sibling in
                sibling.id != current.id
                    && VarietalName.collisionKey(
                        VarietalName.bare(sibling.name, cropNames: one.allCommonNames))
                        == candidateKey
            }
            return collides ? current.name : candidate
        }
        return PlantPage(
            identity: identity,
            displayName: bareCultivarName
                ?? titled(one.preferredCommonName(for: locale))
                ?? one.scientificName,
            commonNames: cultivar?.commonNames ?? one.allCommonNames,
            taxonomy: PlantTaxonomy(
                familyName: family?.name,
                genusName: genus?.name,
                scientificName: one.scientificName,
                cultivarName: bareCultivarName
            ),
            conditions: GrowingConditions.merged(species: one, cultivar: cultivar),
            threats: threats,
            currentPlantings: currentPlantings(
                from: relevantPlantings, locationNames: locationNames),
            activity: activity(from: relevantPlantings, locationNames: locationNames),
            image: try image(speciesID: one.id, cultivarID: cultivar?.id)
        )
    }

    private func image(speciesID: Species.ID, cultivarID: Cultivar.ID?) throws -> PlantImage? {
        let imagesByOwner = try images.imagesByOwner()
        if let cultivarID, let own = imagesByOwner[cultivarID.rawValue] {
            return own
        }
        return imagesByOwner[speciesID.rawValue]
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

}

extension PlantPageLoader {
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

    private func cultivarScientificName(quoting name: String, parent: Species?) -> String {
        guard let parent else { return name }
        return "\(parent.scientificName) '\(name)'"
    }

    private func titled(_ name: String?) -> String? {
        guard let name, let first = name.first else { return name }
        return first.uppercased() + name.dropFirst()
    }
}
