import Domain
import Persistence

public enum PlantAdoptionError: Error, Hashable {
    case unknownIdentity(String)
    case brokenChain(String)
}

public struct AdoptionReceipt {
    enum Created {
        case family(PlantFamily.ID)
        case genus(Genus.ID)
        case species(Species.ID)
        case cultivar(Cultivar.ID)
    }

    var created: [Created] = []

    public var isEmpty: Bool { created.isEmpty }
}

public struct PlantAdopter {
    private let personal: AppDatabase
    private let knowledge: AppDatabase?

    public init(personal: AppDatabase, knowledge: AppDatabase?) {
        self.personal = personal
        self.knowledge = knowledge
    }

    @discardableResult
    public func adopt(_ identity: PlantIdentity) throws -> AdoptionReceipt {
        var receipt = AdoptionReceipt()
        switch identity {
        case .species(let id):
            try adoptSpecies(id, into: &receipt)
        case .cultivar(let id):
            try adoptCultivar(id, into: &receipt)
        }
        return receipt
    }

    public func undo(_ receipt: AdoptionReceipt) {
        for created in receipt.created.reversed() {
            switch created {
            case .cultivar(let id):
                _ = try? CultivarRepository(personal).delete(id: id)
            case .species(let id):
                _ = try? SpeciesRepository(personal).delete(id: id)
            case .genus(let id):
                _ = try? GenusRepository(personal).delete(id: id)
            case .family(let id):
                _ = try? PlantFamilyRepository(personal).delete(id: id)
            }
        }
    }

    private func adoptCultivar(_ id: Cultivar.ID, into receipt: inout AdoptionReceipt) throws {
        if try CultivarRepository(personal).fetch(id: id) != nil {
            return
        }
        guard let knowledge,
            let cultivar = try CultivarRepository(knowledge).fetch(id: id)
        else {
            throw PlantAdoptionError.unknownIdentity(id.rawValue)
        }
        try adoptSpecies(cultivar.speciesID, into: &receipt)
        try CultivarRepository(personal).insert(cultivar)
        receipt.created.append(.cultivar(cultivar.id))
    }

    private func adoptSpecies(_ id: Species.ID, into receipt: inout AdoptionReceipt) throws {
        if try SpeciesRepository(personal).fetch(id: id) != nil {
            return
        }
        guard let knowledge,
            let species = try SpeciesRepository(knowledge).fetch(id: id)
        else {
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
            receipt.created.append(.family(family.id))
        }
        if try GenusRepository(personal).fetch(id: genus.id) == nil {
            try GenusRepository(personal).insert(genus)
            receipt.created.append(.genus(genus.id))
        }
        try SpeciesRepository(personal).insert(species)
        receipt.created.append(.species(species.id))
    }
}
