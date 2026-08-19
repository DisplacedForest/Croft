import Domain
import Foundation
import Graph
import Persistence

struct KnowledgeMapper {
    let inputs: KnowledgeImporter.Inputs

    func map(into summary: inout ImportSummary) throws -> MappedKnowledge {
        var mapped = MappedKnowledge()
        mapped.inputVersions = [
            inputs.profiles.meta.name: inputs.profiles.meta.version,
            inputs.catalog.meta.name: inputs.catalog.meta.version,
            inputs.pestDisease.meta.name: inputs.pestDisease.meta.version,
        ]
        for meta in [inputs.profiles.meta, inputs.catalog.meta, inputs.pestDisease.meta] {
            if let provenance = meta.provenance {
                mapped.inputProvenance[meta.name] = provenance
            }
        }
        let taxonomy = try mapTaxonomy(into: &mapped, summary: &summary)
        let cultivarIndex = try mapCatalog(taxonomy, into: &mapped, summary: &summary)
        try mapPestsAndDiseases(
            taxonomy, cultivars: cultivarIndex, into: &mapped, summary: &summary)
        try mapImages(taxonomy, into: &mapped)
        mapped.families.sort { $0.id.rawValue < $1.id.rawValue }
        mapped.genera.sort { $0.id.rawValue < $1.id.rawValue }
        mapped.species.sort { $0.id.rawValue < $1.id.rawValue }
        mapped.cultivars.sort { $0.id.rawValue < $1.id.rawValue }
        mapped.pests.sort { $0.id.rawValue < $1.id.rawValue }
        mapped.diseases.sort { $0.id.rawValue < $1.id.rawValue }
        mapped.pathogens.sort { $0.id.rawValue < $1.id.rawValue }
        mapped.plantRefs.sort { $0.id < $1.id }
        mapped.edges.sort { $0.id < $1.id }
        mapped.edges = try mapped.edges.reduce(into: []) { result, edge in
            guard let last = result.last, last.id == edge.id else {
                result.append(edge)
                return
            }
            if last != edge {
                throw ImportError.conflictingDuplicateEdge(
                    id: edge.id, fields: Self.conflictingFields(last, edge))
            }
        }
        mapped.attributions.sort {
            $0.recordID == $1.recordID
                ? $0.citation < $1.citation : $0.recordID < $1.recordID
        }
        mapped.attributions = mapped.attributions.reduce(into: []) { result, attribution in
            if result.last ?? ("", "") != attribution {
                result.append(attribution)
            }
        }
        return mapped
    }

    static func conflictingFields(_ lhs: PlannedEdge, _ rhs: PlannedEdge) -> [String] {
        var fields: [String] = []
        if lhs.source != rhs.source { fields.append("source") }
        if lhs.target != rhs.target { fields.append("target") }
        if lhs.provenance.source != rhs.provenance.source { fields.append("provenance.source") }
        if lhs.provenance.sourceType != rhs.provenance.sourceType {
            fields.append("provenance.source_type")
        }
        if lhs.provenance.confidence != rhs.provenance.confidence {
            fields.append("provenance.confidence")
        }
        if lhs.provenance.notes != rhs.provenance.notes { fields.append("provenance.notes") }
        return fields
    }

    struct Taxonomy {
        var speciesByCrop: [String: String] = [:]

        func hostSpecies(for crop: String) -> [String]? {
            if crop == "squash" {
                let both = ["summer-squash", "winter-squash"].compactMap { speciesByCrop[$0] }
                return both.isEmpty ? nil : both
            }
            return speciesByCrop[crop].map { [$0] }
        }

        func cultivarParent(for crop: String) -> String? {
            crop == "squash" ? nil : speciesByCrop[crop]
        }
    }

    private func mapTaxonomy(
        into mapped: inout MappedKnowledge,
        summary: inout ImportSummary
    ) throws -> Taxonomy {
        var taxonomy = Taxonomy()
        var familyIDs: [String: String] = [:]
        var genusIDs: [String: String] = [:]
        for profile in inputs.profiles.crops {
            let speciesID = KnowledgeID.species(profile.latinName)
            guard taxonomy.speciesByCrop[profile.crop] == nil else {
                throw ImportError.duplicateRecord("crop \(profile.crop)")
            }
            let familyID = try mapFamily(profile, ids: &familyIDs, into: &mapped)
            let genusID = try mapGenus(profile, familyID: familyID, ids: &genusIDs, into: &mapped)
            guard !mapped.species.contains(where: { $0.id.rawValue == speciesID }) else {
                throw ImportError.duplicateRecord(speciesID)
            }
            mapped.species.append(
                species(from: profile, id: speciesID, genusID: genusID, summary: &summary))
            mapped.plantRefs.append(EntityRef(id: speciesID, type: .plant))
            taxonomy.speciesByCrop[profile.crop] = speciesID
            for citation in Set(profile.citations).sorted() {
                mapped.attributions.append((speciesID, citation))
            }
        }
        return taxonomy
    }

    private func mapFamily(
        _ profile: CropProfile,
        ids: inout [String: String],
        into mapped: inout MappedKnowledge
    ) throws -> String {
        let parts = KnowledgeVocabulary.familyParts(profile.family)
        let familyID = KnowledgeID.family(parts.name)
        if ids[parts.name] == nil {
            ids[parts.name] = familyID
            mapped.families.append(
                PlantFamily(
                    id: PlantFamily.ID(rawValue: familyID),
                    name: parts.name,
                    commonNames: parts.commonNames
                ))
        }
        return familyID
    }

    private func mapGenus(
        _ profile: CropProfile,
        familyID: String,
        ids: inout [String: String],
        into mapped: inout MappedKnowledge
    ) throws -> String {
        guard let genusName = profile.latinName.split(separator: " ").first else {
            throw ImportError.unmappableValue(
                record: profile.crop, field: "latin_name", value: profile.latinName)
        }
        let name = String(genusName)
        let genusID = KnowledgeID.genus(name)
        if let existing = ids[name] {
            return existing
        }
        ids[name] = genusID
        mapped.genera.append(
            Genus(
                id: Genus.ID(rawValue: genusID),
                familyID: PlantFamily.ID(rawValue: familyID),
                name: name
            ))
        return genusID
    }

    private func localizedNames(for cropSlug: String) -> [LocalizedPlantName] {
        guard let file = inputs.localizedNames else {
            return []
        }
        return file.names
            .filter { $0.crop == cropSlug }
            .sorted { $0.locale < $1.locale }
            .map { LocalizedPlantName(locale: $0.locale, name: $0.name) }
    }

    private func species(
        from profile: CropProfile,
        id: String,
        genusID: String,
        summary: inout ImportSummary
    ) -> Species {
        let temps = profile.germinationSoilTempF
        let proseMaturity =
            profile.daysToMaturityTypicalRange != nil
            && Units.intRange(profile.daysToMaturityTypicalRange) == nil
        if proseMaturity {
            summary.normalize("species_prose_days_to_maturity")
        }
        let proseDepth =
            profile.sowingDepthIn != nil
            && Units.centimeterRange(fromInches: profile.sowingDepthIn) == nil
        if proseDepth {
            summary.normalize("species_prose_sowing_depth")
        }
        if profile.lifeCycle != nil, profile.lifeCycle?.contains(" ") == true {
            summary.normalize("species_compound_life_cycle")
        }
        return Species(
            id: Species.ID(rawValue: id),
            genusID: Genus.ID(rawValue: genusID),
            scientificName: profile.latinName,
            commonNames: [KnowledgeVocabulary.humanized(cropSlug: profile.crop)],
            localizedCommonNames: localizedNames(for: profile.crop),
            lifeCycle: KnowledgeVocabulary.lifeCycle(profile.lifeCycle),
            sunExposure: KnowledgeVocabulary.sunExposure(profile.sun),
            soilPH: Units.doubleRange(profile.phRange),
            spacingCentimeters: Units.centimeterRange(fromInches: profile.spacingIn?.plant),
            daysToMaturity: Units.intRange(profile.daysToMaturityTypicalRange),
            germinationTempMin: temps?.min.map(Units.celsius(fromFahrenheit:)),
            germinationTempOptimal: Units.celsiusRange(fromFahrenheit: temps?.optimal),
            germinationTempMax: temps?.max.map(Units.celsius(fromFahrenheit:)),
            germinationDays: Units.intRange(profile.germinationDaysTypical),
            sowingDepthCentimeters: Units.centimeterRange(fromInches: profile.sowingDepthIn),
            rowSpacingCentimeters: Units.centimeterRange(fromInches: profile.spacingIn?.row),
            sowingMethod: KnowledgeVocabulary.sowingMethod(profile.sowingMethod),
            weeksIndoorsBeforeTransplant: Units.intRange(profile.weeksIndoorsBeforeTransplant),
            frostTolerance: KnowledgeVocabulary.frostTolerance(profile.frostTolerance),
            transplantSoilTempMin: profile.soilTempTransplantMinF.map(
                Units.celsius(fromFahrenheit:)),
            daysToMaturityBasis: KnowledgeVocabulary.maturityBasis(profile.daysToMaturityBasis)
        )
    }
}
