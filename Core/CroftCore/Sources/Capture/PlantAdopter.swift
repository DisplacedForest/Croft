import Domain
import Persistence

public enum PlantAdoptionError: Error, Hashable {
    case unknownIdentity(String)
    case brokenChain(String)
}

public struct PlantAdopter {
    private let personal: AppDatabase
    private let knowledge: AppDatabase?

    public init(personal: AppDatabase, knowledge: AppDatabase?) {
        self.personal = personal
        self.knowledge = knowledge
    }

    @discardableResult
    public func adopt(_ identity: PlantIdentity) throws -> PlantIdentity {
        switch identity {
        case .species(let id):
            try adoptSpecies(id)
        case .cultivar(let id):
            try adoptCultivar(id)
        }
        return identity
    }

    private func adoptCultivar(_ id: Cultivar.ID) throws {
        if try CultivarRepository(personal).fetch(id: id) != nil {
            return
        }
        guard let knowledge else {
            throw PlantAdoptionError.unknownIdentity(id.rawValue)
        }
        guard let cultivar = try CultivarRepository(knowledge).fetch(id: id) else {
            throw PlantAdoptionError.unknownIdentity(id.rawValue)
        }
        try adoptSpecies(cultivar.speciesID)
        try CultivarRepository(personal).insert(cultivar)
    }

    private func adoptSpecies(_ id: Species.ID) throws {
        if try SpeciesRepository(personal).fetch(id: id) != nil {
            return
        }
        guard let knowledge else {
            throw PlantAdoptionError.unknownIdentity(id.rawValue)
        }
        guard let species = try SpeciesRepository(knowledge).fetch(id: id) else {
            throw PlantAdoptionError.unknownIdentity(id.rawValue)
        }
        guard let genus = try GenusRepository(knowledge).fetch(id: species.genusID) else {
            throw PlantAdoptionError.brokenChain(species.genusID.rawValue)
        }
        guard let family = try PlantFamilyRepository(knowledge).fetch(id: genus.familyID) else {
            throw PlantAdoptionError.brokenChain(genus.familyID.rawValue)
        }
        if try PlantFamilyRepository(personal).fetch(id: family.id) == nil {
            try PlantFamilyRepository(personal).insert(family)
        }
        if try GenusRepository(personal).fetch(id: genus.id) == nil {
            try GenusRepository(personal).insert(genus)
        }
        try SpeciesRepository(personal).insert(species)
    }
}
