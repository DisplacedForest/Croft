import Domain
import Foundation
import GRDB
import Graph
import Persistence

public struct CompanionNote: Equatable, Sendable {
    public let plantName: String
    public let source: String
    public let isAntagonist: Bool

    public init(plantName: String, source: String, isAntagonist: Bool) {
        self.plantName = plantName
        self.source = source
        self.isAntagonist = isAntagonist
    }
}

public struct CompanionAdvice: Sendable {
    private let databases: [AppDatabase]
    private let knowledgeSpecies: SpeciesRepository
    private let personalSpecies: SpeciesRepository
    private let knowledgeCultivars: CultivarRepository
    private let personalCultivars: CultivarRepository
    private let plantings: PlantingRepository

    public init(knowledge: AppDatabase, personal: AppDatabase) {
        databases = [knowledge, personal]
        knowledgeSpecies = SpeciesRepository(knowledge)
        personalSpecies = SpeciesRepository(personal)
        knowledgeCultivars = CultivarRepository(knowledge)
        personalCultivars = CultivarRepository(personal)
        plantings = PlantingRepository(personal)
    }

    public init(_ database: AppDatabase) {
        self.init(knowledge: database, personal: database)
    }

    public func notes(
        for candidate: PlantIdentity,
        inBed bedID: Bed.ID
    ) throws -> [CompanionNote] {
        guard let candidateSpecies = try speciesID(of: candidate) else {
            return []
        }
        let neighbors = try neighborSpecies(inBed: bedID, excluding: candidateSpecies)
        guard !neighbors.isEmpty else {
            return []
        }
        var antagonist: CompanionNote?
        var companion: CompanionNote?
        for database in databases {
            let found = try database.writer.read { db in
                (
                    try note(
                        .antagonisticTo, candidate: candidateSpecies, neighbors: neighbors,
                        isAntagonist: true, in: db),
                    try note(
                        .companionWith, candidate: candidateSpecies, neighbors: neighbors,
                        isAntagonist: false, in: db)
                )
            }
            antagonist = antagonist ?? found.0
            companion = companion ?? found.1
        }
        return [antagonist, companion].compactMap { $0 }
    }

    private func note(
        _ type: RelationshipType,
        candidate: Species.ID,
        neighbors: [Species.ID: String],
        isAntagonist: Bool,
        in db: Database
    ) throws -> CompanionNote? {
        let candidateID = candidate.rawValue
        let edges =
            (try GraphStore.outgoing(from: candidateID, via: type, in: db)
            + GraphStore.incoming(to: candidateID, via: type, in: db))
            .sorted { $0.id < $1.id }
        for edge in edges {
            let otherID = edge.source.id == candidateID ? edge.target.id : edge.source.id
            guard let name = neighbors[Species.ID(rawValue: otherID)] else {
                continue
            }
            guard let source = edge.provenance.source, !source.isEmpty else {
                continue
            }
            return CompanionNote(plantName: name, source: source, isAntagonist: isAntagonist)
        }
        return nil
    }

    private func neighborSpecies(
        inBed bedID: Bed.ID,
        excluding candidate: Species.ID
    ) throws -> [Species.ID: String] {
        var neighbors: [Species.ID: String] = [:]
        for planting in try plantings.plantings(inBed: bedID)
        where planting.status == .active {
            guard
                let species = try speciesID(of: planting.identity),
                species != candidate,
                neighbors[species] == nil
            else {
                continue
            }
            neighbors[species] = try speciesName(species)
        }
        return neighbors
    }

    private func speciesID(of identity: PlantIdentity) throws -> Species.ID? {
        switch identity {
        case .species(let id):
            return id
        case .cultivar(let id):
            let cultivar =
                try knowledgeCultivars.fetch(id: id) ?? personalCultivars.fetch(id: id)
            return cultivar?.speciesID
        }
    }

    private func speciesName(_ id: Species.ID) throws -> String {
        guard
            let species = try knowledgeSpecies.fetch(id: id) ?? personalSpecies.fetch(id: id)
        else {
            return "unknown plant"
        }
        guard let name = species.commonNames.first, let first = name.first else {
            return species.scientificName
        }
        return first.uppercased() + name.dropFirst()
    }
}
