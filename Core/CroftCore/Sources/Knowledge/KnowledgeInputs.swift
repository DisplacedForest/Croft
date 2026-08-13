import Foundation

public struct StringList: Decodable, Equatable, Sendable {
    public let values: [String]

    public init(values: [String]) {
        self.values = values
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            values = []
        } else if let single = try? container.decode(String.self) {
            values = [single]
        } else {
            values = try container.decode([String].self)
        }
    }
}

public struct InputMeta: Decodable, Sendable {
    public let name: String
    public let version: String
    public let provenance: String?
}

public struct CropProfilesFile: Decodable, Sendable {
    public let meta: InputMeta
    public let crops: [CropProfile]
}

public struct CropProfile: Decodable, Sendable {
    public struct GerminationTemps: Decodable, Sendable {
        public let min: Double?
        public let optimal: String?
        public let max: Double?
    }

    public struct Spacing: Decodable, Sendable {
        public let plant: String?
        public let row: String?
    }

    public let crop: String
    public let latinName: String
    public let family: String
    public let sun: String?
    public let germinationSoilTempF: GerminationTemps?
    public let germinationDaysTypical: String?
    public let sowingDepthIn: String?
    public let spacingIn: Spacing?
    public let sowingMethod: String?
    public let weeksIndoorsBeforeTransplant: String?
    public let frostTolerance: String?
    public let soilTempTransplantMinF: Double?
    public let daysToMaturityTypicalRange: String?
    public let daysToMaturityBasis: String?
    public let phRange: String?
    public let lifeCycle: String?
    public let citations: [String]

    enum CodingKeys: String, CodingKey {
        case crop
        case latinName = "latin_name"
        case family
        case sun
        case germinationSoilTempF = "germination_soil_temp_f"
        case germinationDaysTypical = "germination_days_typical"
        case sowingDepthIn = "sowing_depth_in"
        case spacingIn = "spacing_in"
        case sowingMethod = "sowing_method"
        case weeksIndoorsBeforeTransplant = "weeks_indoors_before_transplant"
        case frostTolerance = "frost_tolerance"
        case soilTempTransplantMinF = "soil_temp_transplant_min_f"
        case daysToMaturityTypicalRange = "days_to_maturity_typical_range"
        case daysToMaturityBasis = "days_to_maturity_basis"
        case phRange = "ph_range"
        case lifeCycle = "life_cycle"
        case citations
    }
}

public struct CatalogFile: Decodable, Sendable {
    public let meta: InputMeta
    public let cultivars: [CatalogRow]
}

public struct CatalogRow: Decodable, Sendable {
    public struct MaturityDays: Decodable, Sendable {
        public let min: Int?
        public let max: Int?
    }

    public let cultivar: String
    public let crop: String
    public let daysToMaturity: MaturityDays?
    public let plantSpacing: StringList?
    public let plantingSeason: StringList?
    public let lifeCycle: StringList?
    public let sowingMethod: StringList?
    public let seedType: StringList?
    public let heirloom: Bool?
    public let growthHabit: StringList?
    public let seedPrep: StringList?
    public let dataOrigin: String?

    enum CodingKeys: String, CodingKey {
        case cultivar
        case crop
        case daysToMaturity = "days_to_maturity"
        case plantSpacing = "plant_spacing"
        case plantingSeason = "planting_season"
        case lifeCycle = "life_cycle"
        case sowingMethod = "sowing_method"
        case seedType = "seed_type"
        case heirloom
        case growthHabit = "growth_habit"
        case seedPrep = "seed_prep"
        case dataOrigin = "data_origin"
    }
}

public struct PlantImagesFile: Decodable, Sendable {
    public let meta: InputMeta
    public let images: [PlantImageInput]
}

public struct PlantImageInput: Decodable, Sendable {
    public enum OwnerKind: String, Decodable, Sendable {
        case species
        case cultivar
    }

    public let slug: String
    public let ownerKind: OwnerKind
    public let kind: String
    public let file: String?
    public let sha256: String?
    public let sourceTitle: String?
    public let sourcePageURL: String?
    public let sourceFileURL: String?
    public let license: String?
    public let licenseURL: String?
    public let artist: String?

    enum CodingKeys: String, CodingKey {
        case slug
        case ownerKind = "owner_kind"
        case kind
        case file
        case sha256
        case sourceTitle = "source_title"
        case sourcePageURL = "source_page_url"
        case sourceFileURL = "source_file_url"
        case license
        case licenseURL = "license_url"
        case artist
    }
}

public struct PestDiseaseFile: Decodable, Sendable {
    public let meta: InputMeta
    public let pests: [PestInput]
    public let diseases: [DiseaseInput]
    public let cultivarResistanceExamples: [ResistanceExample]

    enum CodingKeys: String, CodingKey {
        case meta
        case pests
        case diseases
        case cultivarResistanceExamples = "cultivar_resistance_examples"
    }
}

public struct PestInput: Decodable, Sendable {
    public struct Biology: Decodable, Sendable {
        public let lifecycle: String?
    }

    public let id: String
    public let commonName: String
    public let scientificName: String?
    public let hosts: [String]
    public let biology: Biology?
    public let damage: String?
    public let vectorOf: [String]?
    public let identification: String?
    public let citations: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case commonName = "common_name"
        case scientificName = "scientific_name"
        case hosts
        case biology
        case damage
        case vectorOf = "vector_of"
        case identification
        case citations
    }
}

public struct DiseaseInput: Decodable, Sendable {
    public let id: String
    public let name: String
    public let pathogen: String?
    public let pathogenType: String
    public let hosts: [String]
    public let symptoms: String?
    public let transmission: String?
    public let management: [String]?
    public let vectors: [String]?
    public let citations: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case pathogen
        case pathogenType = "pathogen_type"
        case hosts
        case symptoms
        case transmission
        case management
        case vectors
        case citations
    }
}

public struct ResistanceExample: Decodable, Sendable {
    public let crop: String
    public let cultivar: String
    public let resistances: [String]
    public let codes: String?
    public let daysToMaturity: Int?
    public let notes: String?
    public let source: String?
    public let verification: String?

    enum CodingKeys: String, CodingKey {
        case crop
        case cultivar
        case resistances
        case codes
        case daysToMaturity = "days_to_maturity"
        case notes
        case source
        case verification
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        crop = try container.decode(String.self, forKey: .crop)
        cultivar = try container.decode(String.self, forKey: .cultivar)
        resistances = try container.decodeIfPresent([String].self, forKey: .resistances) ?? []
        codes = try container.decodeIfPresent(String.self, forKey: .codes)
        if let days = try? container.decodeIfPresent(Int.self, forKey: .daysToMaturity) {
            daysToMaturity = days
        } else {
            daysToMaturity = nil
        }
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        verification = try container.decodeIfPresent(String.self, forKey: .verification)
    }
}
