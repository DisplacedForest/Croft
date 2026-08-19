import Domain
import Foundation
import Graph

extension KnowledgeMapper {
    struct ReferenceIDs {
        let pests: Set<String>
        let diseases: Set<String>
    }

    func mapPestsAndDiseases(
        _ taxonomy: Taxonomy,
        cultivars: [String: Int],
        into mapped: inout MappedKnowledge,
        summary: inout ImportSummary
    ) throws {
        let known = ReferenceIDs(
            pests: Set(inputs.pestDisease.pests.map { KnowledgeID.pest($0.id) }),
            diseases: Set(inputs.pestDisease.diseases.map { KnowledgeID.disease($0.id) })
        )
        try mapPests(taxonomy, diseaseIDs: known.diseases, into: &mapped)
        try mapDiseases(taxonomy, pestIDs: known.pests, into: &mapped, summary: &summary)
        try mapResistanceExamples(
            taxonomy, cultivars: cultivars, known: known,
            into: &mapped, summary: &summary
        )
    }

    private func mapPests(
        _ taxonomy: Taxonomy,
        diseaseIDs: Set<String>,
        into mapped: inout MappedKnowledge
    ) throws {
        for input in inputs.pestDisease.pests {
            let pestID = KnowledgeID.pest(input.id)
            guard !mapped.pests.contains(where: { $0.id.rawValue == pestID }) else {
                throw ImportError.duplicateRecord(pestID)
            }
            mapped.pests.append(
                Pest(
                    id: Pest.ID(rawValue: pestID),
                    commonName: input.commonName,
                    scientificName: input.scientificName,
                    organismType: .pest,
                    description: input.identification,
                    lifeCycle: input.biology?.lifecycle,
                    typicalDamage: input.damage
                ))
            let provenance = provenance(citations: input.citations)
            let pestRef = EntityRef(id: pestID, type: .pest)
            let hostNotes = try validatedHostNotes(
                input.hostNotes, hosts: input.hosts, record: input.id)
            for host in try hostRefs(input.hosts, record: input.id, taxonomy: taxonomy) {
                var noted = provenance
                noted.notes = hostNotes[host.host]
                mapped.edges.append(edge(from: host.ref, .hostOf, to: pestRef, noted))
            }
            for target in input.vectorOf ?? [] {
                let diseaseID = KnowledgeID.disease(target)
                guard diseaseIDs.contains(diseaseID) else {
                    throw ImportError.unknownReference(record: input.id, reference: target)
                }
                let diseaseRef = EntityRef(id: diseaseID, type: .disease)
                mapped.edges.append(edge(from: pestRef, .vectorOf, to: diseaseRef, provenance))
            }
            for citation in Set(input.citations).sorted() {
                mapped.attributions.append((pestID, citation))
            }
        }
    }

    private func mapDiseases(
        _ taxonomy: Taxonomy,
        pestIDs: Set<String>,
        into mapped: inout MappedKnowledge,
        summary: inout ImportSummary
    ) throws {
        var pathogenIDs: Set<String> = []
        for input in inputs.pestDisease.diseases {
            let diseaseID = KnowledgeID.disease(input.id)
            guard !mapped.diseases.contains(where: { $0.id.rawValue == diseaseID }) else {
                throw ImportError.duplicateRecord(diseaseID)
            }
            guard let pathogenType = KnowledgeVocabulary.pathogenType(input.pathogenType) else {
                throw ImportError.unmappableValue(
                    record: input.id, field: "pathogen_type", value: input.pathogenType)
            }
            if pathogenType.normalized {
                summary.normalize("disease_pathogen_type_normalized")
            }
            mapped.diseases.append(
                Disease(
                    id: Disease.ID(rawValue: diseaseID),
                    name: input.name,
                    pathogen: input.pathogen,
                    pathogenType: pathogenType.type,
                    symptoms: input.symptoms,
                    transmission: input.transmission,
                    management: input.management ?? []
                ))
            let provenance = provenance(citations: input.citations)
            let diseaseRef = EntityRef(id: diseaseID, type: .disease)
            let hostNotes = try validatedHostNotes(
                input.hostNotes, hosts: input.hosts, record: input.id)
            for host in try hostRefs(input.hosts, record: input.id, taxonomy: taxonomy) {
                var noted = provenance
                noted.notes = hostNotes[host.host]
                mapped.edges.append(
                    edge(from: host.ref, .susceptibleTo, to: diseaseRef, noted))
            }
            try mapPathogen(input, diseaseRef: diseaseRef, ids: &pathogenIDs, into: &mapped)
            for vector in input.vectors ?? [] {
                let pestID = KnowledgeID.pest(vector)
                guard pestIDs.contains(pestID) else {
                    throw ImportError.unknownReference(record: input.id, reference: vector)
                }
                let pestRef = EntityRef(id: pestID, type: .pest)
                mapped.edges.append(edge(from: pestRef, .vectorOf, to: diseaseRef, provenance))
            }
            for citation in Set(input.citations).sorted() {
                mapped.attributions.append((diseaseID, citation))
            }
        }
    }

    private func mapPathogen(
        _ input: DiseaseInput,
        diseaseRef: EntityRef,
        ids: inout Set<String>,
        into mapped: inout MappedKnowledge
    ) throws {
        guard let name = input.pathogen, !name.isEmpty else {
            return
        }
        let pathogenID = KnowledgeID.pathogen(name)
        if ids.insert(pathogenID).inserted {
            mapped.pathogens.append(
                Pathogen(id: Pathogen.ID(rawValue: pathogenID), name: name))
        }
        let pathogenRef = EntityRef(id: pathogenID, type: .pathogen)
        mapped.edges.append(
            edge(
                from: diseaseRef, .causedBy, to: pathogenRef, provenance(citations: input.citations)
            ))
    }

    private func mapResistanceExamples(
        _ taxonomy: Taxonomy,
        cultivars: [String: Int],
        known: ReferenceIDs,
        into mapped: inout MappedKnowledge,
        summary: inout ImportSummary
    ) throws {
        for example in inputs.pestDisease.cultivarResistanceExamples {
            var crop = example.crop
            if crop == "squash" {
                let resolution = SquashClassification.classify(cultivarNamed: example.cultivar)
                if case .crop(let resolved) = resolution {
                    crop = resolved
                }
            }
            guard let speciesID = taxonomy.cultivarParent(for: crop) else {
                if taxonomy.hostSpecies(for: crop) != nil {
                    summary.skip("resistance_ambiguous_squash")
                    continue
                }
                throw ImportError.unknownCrop(record: example.cultivar, crop: crop)
            }
            let id = KnowledgeID.cultivar(speciesID: speciesID, name: example.cultivar)
            if let index = cultivars[id] {
                if mapped.cultivars[index].daysToMaturity == nil {
                    mapped.cultivars[index].daysToMaturity =
                        example.daysToMaturity.map { $0...$0 }
                }
            } else if !mapped.cultivars.contains(where: { $0.id.rawValue == id }) {
                mapped.cultivars.append(
                    Cultivar(
                        id: Cultivar.ID(rawValue: id),
                        speciesID: Species.ID(rawValue: speciesID),
                        name: example.cultivar,
                        daysToMaturity: example.daysToMaturity.map { $0...$0 }
                    ))
                mapped.plantRefs.append(EntityRef(id: id, type: .plant))
            }
            let cultivarRef = EntityRef(id: id, type: .plant)
            let provenance = Provenance(
                source: example.verification ?? example.source
                    ?? "cultivar_resistance_examples",
                sourceType: .reference,
                notes: example.codes
            )
            for target in example.resistances {
                let ref = try resistanceTarget(target, record: example.cultivar, known: known)
                mapped.edges.append(edge(from: cultivarRef, .resistantTo, to: ref, provenance))
            }
        }
    }

    private func resistanceTarget(
        _ target: String,
        record: String,
        known: ReferenceIDs
    ) throws -> EntityRef {
        let diseaseID = KnowledgeID.disease(target)
        if known.diseases.contains(diseaseID) {
            return EntityRef(id: diseaseID, type: .disease)
        }
        let pestID = KnowledgeID.pest(target)
        if known.pests.contains(pestID) {
            return EntityRef(id: pestID, type: .pest)
        }
        throw ImportError.unknownReference(record: record, reference: target)
    }

    private func hostRefs(
        _ hosts: [String],
        record: String,
        taxonomy: Taxonomy
    ) throws -> [(host: String, ref: EntityRef)] {
        var refs: [(host: String, ref: EntityRef)] = []
        for host in Set(hosts).sorted() {
            guard let speciesIDs = taxonomy.hostSpecies(for: host) else {
                throw ImportError.unknownCrop(record: record, crop: host)
            }
            refs.append(
                contentsOf: speciesIDs.map { (host, EntityRef(id: $0, type: .plant)) })
        }
        return refs.sorted { $0.ref.id < $1.ref.id }
    }

    private func validatedHostNotes(
        _ notes: [String: String]?,
        hosts: [String],
        record: String
    ) throws -> [String: String] {
        guard let notes else { return [:] }
        for host in notes.keys.sorted() where !hosts.contains(host) {
            throw ImportError.hostNoteWithoutHost(record: record, host: host)
        }
        return notes
    }

    private func provenance(citations: [String]) -> Provenance {
        Provenance(
            source: citations.sorted().first ?? inputs.pestDisease.meta.name,
            sourceType: .reference
        )
    }

    private func edge(
        from source: EntityRef,
        _ type: RelationshipType,
        to target: EntityRef,
        _ provenance: Provenance
    ) -> PlannedEdge {
        PlannedEdge(
            id: KnowledgeID.edge(from: source.id, type: type.rawValue, to: target.id),
            source: source,
            type: type,
            target: target,
            provenance: provenance
        )
    }
}
