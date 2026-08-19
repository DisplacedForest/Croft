import Domain
import Foundation
import GRDB
import Graph
import Persistence

struct PlantThreatResolver: Sendable {
    private let knowledge: AppDatabase
    private let pests: PestRepository
    private let diseases: DiseaseRepository
    private let images: PlantImageStore

    init(knowledge: AppDatabase) {
        self.knowledge = knowledge
        pests = PestRepository(knowledge)
        diseases = DiseaseRepository(knowledge)
        images = PlantImageStore(knowledge)
    }

    func threats(fromPlantIDs plantIDs: [String], hostID: String) throws -> [PlantThreat] {
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
                        summary: edge.provenance.notes ?? pest.typicalDamage ?? pest.description,
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
                        summary: edge.provenance.notes ?? disease.symptoms,
                        affectedParts: disease.affectedPlantParts
                    ))
            default:
                continue
            }
        }
        return try withImages(threats, hostID: hostID).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func withImages(_ threats: [PlantThreat], hostID: String) throws -> [PlantThreat] {
        let threatImages = try images.threatImages(hostID: hostID)
        return threats.map { threat in
            var resolved = threat
            resolved.image = threatImages[threat.id]
            return resolved
        }
    }
}
