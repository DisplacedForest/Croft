import Domain
import Foundation
import Graph

extension KnowledgeMapper {
    private static let skippableCrops: Set<String> = [
        "flower", "other-herb", "other-veg", "other-fruit",
    ]

    func mapCatalog(
        _ taxonomy: Taxonomy,
        into mapped: inout MappedKnowledge,
        summary: inout ImportSummary
    ) throws -> [String: Int] {
        var groups: [String: [CatalogRow]] = [:]
        var groupSpecies: [String: String] = [:]
        for row in inputs.catalog.cultivars {
            var crop = row.crop
            if crop == "squash" {
                switch SquashClassification.classify(cultivarNamed: row.cultivar) {
                case .crop(let resolved):
                    crop = resolved
                case .gourd:
                    summary.skip("catalog_gourd_out_of_scope")
                    continue
                case .unknown:
                    summary.skip("catalog_ambiguous_squash")
                    continue
                }
            }
            guard let speciesID = taxonomy.cultivarParent(for: crop) else {
                if Self.skippableCrops.contains(crop) {
                    summary.skip("catalog_out_of_scope_crop")
                } else if taxonomy.hostSpecies(for: crop) == nil {
                    throw ImportError.unknownCrop(record: row.cultivar, crop: crop)
                }
                continue
            }
            let id = KnowledgeID.cultivar(speciesID: speciesID, name: row.cultivar)
            groups[id, default: []].append(row)
            groupSpecies[id] = speciesID
        }
        var index: [String: Int] = [:]
        for (id, rows) in groups.sorted(by: { $0.key < $1.key }) {
            let speciesID = groupSpecies[id] ?? ""
            let cultivar = merged(id: id, speciesID: speciesID, rows: rows, summary: &summary)
            index[id] = mapped.cultivars.count
            mapped.cultivars.append(cultivar)
            mapped.plantRefs.append(EntityRef(id: id, type: .plant))
        }
        return index
    }

    private func merged(
        id: String,
        speciesID: String,
        rows: [CatalogRow],
        summary: inout ImportSummary
    ) -> Cultivar {
        let ordered = rows.sorted { ($0.dataOrigin ?? "") < ($1.dataOrigin ?? "") }
        let name = ordered.map(\.cultivar).sorted()[0]
        let seedTypes = mapList(ordered, \.seedType, KnowledgeVocabulary.seedType, &summary)
        let heirloom = reconciledHeirloom(ordered, seedTypes: seedTypes, summary: &summary)
        return Cultivar(
            id: Cultivar.ID(rawValue: id),
            speciesID: Species.ID(rawValue: speciesID),
            name: name,
            daysToMaturity: bestMaturity(ordered),
            spacingCentimeters: bestSpacing(ordered, summary: &summary),
            growthHabit: firstGrowthHabit(ordered, summary: &summary),
            plantingSeasons: mapList(
                ordered, \.plantingSeason, KnowledgeVocabulary.plantingSeason, &summary),
            seedPreps: mapList(ordered, \.seedPrep, KnowledgeVocabulary.seedPrep, &summary),
            heirloom: heirloom.flag,
            seedTypes: heirloom.seedTypes
        )
    }

    private func bestMaturity(_ rows: [CatalogRow]) -> ClosedRange<Int>? {
        let candidates = rows.compactMap { row -> (rank: Int, range: ClosedRange<Int>)? in
            guard let days = row.daysToMaturity, let low = days.min ?? days.max else {
                return nil
            }
            let high = days.max ?? low
            guard low <= high else {
                return nil
            }
            let rank = row.dataOrigin?.contains("prose") == true ? 0 : 1
            return (rank, low...high)
        }
        return candidates.min {
            let leftWidth = $0.range.upperBound - $0.range.lowerBound
            let rightWidth = $1.range.upperBound - $1.range.lowerBound
            if $0.rank != $1.rank {
                return $0.rank < $1.rank
            }
            if leftWidth != rightWidth {
                return leftWidth < rightWidth
            }
            return $0.range.lowerBound < $1.range.lowerBound
        }?.range
    }

    private func bestSpacing(
        _ rows: [CatalogRow],
        summary: inout ImportSummary
    ) -> ClosedRange<Double>? {
        let ranked = rows.sorted {
            (($0.dataOrigin == "shopify-tags") ? 0 : 1)
                < (($1.dataOrigin == "shopify-tags") ? 0 : 1)
        }
        for row in ranked {
            for text in row.plantSpacing?.values ?? [] {
                if let range = Units.centimeterRange(fromMeasurement: text) {
                    return range
                }
                summary.skip("catalog_unparsed_spacing")
            }
        }
        return nil
    }

    private func firstGrowthHabit(
        _ rows: [CatalogRow],
        summary: inout ImportSummary
    ) -> GrowthHabit? {
        for row in rows {
            for tag in row.growthHabit?.values ?? [] {
                if let habit = KnowledgeVocabulary.growthHabit(tag) {
                    return habit
                }
                summary.skip("catalog_unmapped_growth_habit")
            }
        }
        return nil
    }

    private func mapList<Value: RawRepresentable>(
        _ rows: [CatalogRow],
        _ key: KeyPath<CatalogRow, StringList?>,
        _ transform: (String) -> Value?,
        _ summary: inout ImportSummary
    ) -> [Value] where Value.RawValue == String {
        var seen: Set<String> = []
        var values: [Value] = []
        for row in rows {
            for raw in row[keyPath: key]?.values ?? [] where seen.insert(raw).inserted {
                if let value = transform(raw) {
                    values.append(value)
                } else {
                    summary.skip("catalog_unmapped_tag")
                }
            }
        }
        return values.sorted { $0.rawValue < $1.rawValue }.reduce(into: []) { result, value in
            if result.last?.rawValue != value.rawValue {
                result.append(value)
            }
        }
    }

    private func reconciledHeirloom(
        _ rows: [CatalogRow],
        seedTypes: [SeedType],
        summary: inout ImportSummary
    ) -> (flag: Bool?, seedTypes: [SeedType]) {
        let flags = rows.compactMap(\.heirloom)
        if flags.contains(true) {
            return (true, seedTypes)
        }
        if flags.contains(false) {
            if seedTypes.contains(.heirloom) {
                summary.normalize("catalog_heirloom_tag_dropped")
                return (false, seedTypes.filter { $0 != .heirloom })
            }
            return (false, seedTypes)
        }
        return (seedTypes.contains(.heirloom) ? true : nil, seedTypes)
    }
}
