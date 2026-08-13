import Domain

enum KnowledgeVocabulary {
    static func sunExposure(_ raw: String?) -> SunExposure? {
        guard let raw = raw?.lowercased() else {
            return nil
        }
        if raw.hasPrefix("full sun") {
            return .fullSun
        }
        if raw.hasPrefix("full shade") {
            return .fullShade
        }
        if raw.contains("partial shade") || raw.contains("part shade") {
            return .partialShade
        }
        if raw.contains("partial sun") || raw.contains("part sun") {
            return .partialSun
        }
        return nil
    }

    static func sowingMethod(_ raw: String?) -> SowingMethod? {
        switch raw {
        case "direct": .direct
        case "transplant": .transplant
        case "both": .both
        case "sets/cloves/crowns": .plantingStock
        default: nil
        }
    }

    static func frostTolerance(_ raw: String?) -> FrostTolerance? {
        switch raw {
        case "tender": .tender
        case "half-hardy": .halfHardy
        case "hardy": .hardy
        default: nil
        }
    }

    static func lifeCycle(_ raw: String?) -> LifeCycle? {
        guard let first = raw?.lowercased().split(separator: " ").first else {
            return nil
        }
        return LifeCycle(rawValue: String(first))
    }

    static func maturityBasis(_ raw: String?) -> DaysToMaturityBasis? {
        guard let raw = raw?.lowercased() else {
            return nil
        }
        if raw.hasPrefix("from transplant") {
            return .fromTransplant
        }
        if raw.hasPrefix("from direct seed") {
            return .fromDirectSow
        }
        let stockPrefixes = [
            "from crowns", "from planting seed tubers",
            "from dormant canes", "from fall-planted cloves",
        ]
        if stockPrefixes.contains(where: raw.hasPrefix) {
            return .fromPlantingStock
        }
        return nil
    }

    static func pathogenType(_ raw: String) -> (type: PathogenType, normalized: Bool)? {
        switch raw {
        case "fungus": (.fungal, false)
        case "bacterium": (.bacterial, false)
        case "virus": (.viral, false)
        case "oomycete": (.oomycete, false)
        case "nematode": (.nematode, false)
        case "physiological": (.physiological, false)
        case "phytoplasma": (.phytoplasma, false)
        case "oomycete / fungus complex": (.oomycete, true)
        case "protist (plasmodiophorid)": (.protist, true)
        default: nil
        }
    }

    static func seedType(_ raw: String) -> SeedType? {
        switch raw {
        case "Open Pollinated Seed": .openPollinated
        case "Hybrid Seed": .hybrid
        case "Heirloom Seed": .heirloom
        case "Organic Seed": .organic
        case "Bulb": .bulb
        case "Root": .root
        default: nil
        }
    }

    static func seedPrep(_ raw: String) -> SeedPrep? {
        switch raw {
        case "Soaking": .soaking
        case "Scarification": .scarification
        case "Stratification": .stratification
        case "Cold Stratification": .coldStratification
        case "Requires Light": .requiresLight
        case "Requires Dark": .requiresDark
        default: nil
        }
    }

    static func plantingSeason(_ raw: String) -> PlantingSeason? {
        switch raw {
        case "Spring": .spring
        case "Summer": .summer
        case "Fall": .fall
        case "Winter": .winter
        case "Cool Season": .coolSeason
        case "Warm Season": .warmSeason
        default: nil
        }
    }

    static func growthHabit(_ raw: String) -> GrowthHabit? {
        switch raw.lowercased() {
        case "upright", "branching", "bunching": .upright
        case "bush", "compact bush", "compact", "mounding", "shrub",
            "determinate", "semi-determinate":
            .bush
        case "vining", "climbing", "pole", "indeterminate": .vine
        case "creeping", "ground cover", "spreading": .sprawling
        case "clumping": .clumping
        default: nil
        }
    }

    static func familyParts(_ raw: String) -> (name: String, commonNames: [String]) {
        guard let open = raw.firstIndex(of: "(") else {
            return (raw.trimmingCharacters(in: .whitespaces), [])
        }
        let name = String(raw[..<open]).trimmingCharacters(in: .whitespaces)
        let inner = raw[raw.index(after: open)...].prefix { $0 != ")" }
        let commonNames =
            inner
            .split(separator: "/")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return (name, commonNames)
    }

    static func humanized(cropSlug: String) -> String {
        cropSlug.split(separator: "-").joined(separator: " ")
    }
}
