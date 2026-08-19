import Foundation
import Knowledge

struct KnowledgeFixture {
    let directory: URL
    let imagesDirectory: URL
    let output: URL

    init(
        cropProfiles: String = KnowledgeFixture.cropProfiles,
        catalog: String = KnowledgeFixture.catalog,
        pestDisease: String = KnowledgeFixture.pestDisease,
        images: String? = nil,
        imageFiles: [String: Data] = [:],
        pinnedOverrides: [String: String] = [:],
        unpinned: Set<String> = []
    ) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("knowledge-fixture-\(UUID().uuidString)", isDirectory: true)
        imagesDirectory = directory.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: imagesDirectory, withIntermediateDirectories: true)
        output = directory.appendingPathComponent("snapshot.sqlite")
        var pinned: [String: String] = [:]
        var files = [
            KnowledgeImporter.cropProfilesFile: cropProfiles,
            KnowledgeImporter.catalogFile: catalog,
            KnowledgeImporter.pestDiseaseFile: pestDisease,
        ]
        files[KnowledgeImporter.plantImagesFile] = images
        for (name, contents) in files {
            let data = Data(contents.utf8)
            try data.write(to: directory.appendingPathComponent(name))
            pinned[name] = InputsLock.checksum(of: data)
        }
        for (name, data) in imageFiles {
            try data.write(to: imagesDirectory.appendingPathComponent(name))
        }
        for (name, checksum) in pinnedOverrides {
            pinned[name] = checksum
        }
        for name in unpinned {
            pinned[name] = nil
        }
        let lock = InputsLock(pinned: pinned)
        try lock.encoded().write(to: directory.appendingPathComponent(InputsLock.fileName))
    }

    var importer: KnowledgeImporter {
        KnowledgeImporter(inputDirectory: directory, imagesDirectory: imagesDirectory)
    }

    @discardableResult
    func build() throws -> ImportSummary {
        try importer.buildSnapshot(at: output)
    }
}

extension KnowledgeFixture {
    static let cropProfiles = """
        {
          "meta": {"name": "crop-profiles", "version": "0.1.0", "provenance": "fixture crops"},
          "crops": [
            {
              "crop": "tomato",
              "latin_name": "Solanum lycopersicum",
              "family": "Solanaceae (nightshade)",
              "sun": "full sun (6+ h)",
              "germination_soil_temp_f": {"min": 50, "optimal": "65-85", "max": 95},
              "germination_days_typical": "5-10",
              "sowing_depth_in": "0.25",
              "spacing_in": {"plant": "18-36", "row": "36-60"},
              "sowing_method": "transplant",
              "weeks_indoors_before_transplant": "5-8",
              "frost_tolerance": "tender",
              "soil_temp_transplant_min_f": 60,
              "days_to_maturity_typical_range": "60-90",
              "days_to_maturity_basis": "from transplant",
              "ph_range": "6.0-6.8",
              "life_cycle": "annual",
              "citations": ["https://example.org/tomato"]
            },
            {
              "crop": "summer-squash",
              "latin_name": "Cucurbita pepo",
              "family": "Cucurbitaceae (gourd)",
              "sun": "full sun (6+ h)",
              "germination_soil_temp_f": {"min": 60, "optimal": "85-95", "max": 105},
              "sowing_depth_in": "0.5-1",
              "spacing_in": {"plant": "12-24", "row": "36-72"},
              "sowing_method": "both",
              "frost_tolerance": "tender",
              "days_to_maturity_typical_range": "50-65",
              "days_to_maturity_basis": "from direct seed",
              "ph_range": "6.0-6.8",
              "life_cycle": "annual",
              "citations": ["https://example.org/summer-squash"]
            },
            {
              "crop": "winter-squash",
              "latin_name": "Cucurbita maxima",
              "family": "Cucurbitaceae (gourd)",
              "sun": "full sun (6+ h)",
              "germination_soil_temp_f": {"min": 60, "optimal": "85-95", "max": 105},
              "sowing_depth_in": "set crowns level with the soil",
              "spacing_in": {"plant": "18-48", "row": "48-144"},
              "sowing_method": "sets/cloves/crowns",
              "frost_tolerance": "half-hardy",
              "days_to_maturity_typical_range": "no harvest in year 1",
              "days_to_maturity_basis": "from crowns; establishment first",
              "ph_range": "6.0-6.8",
              "life_cycle": "perennial grown as annual",
              "citations": ["https://example.org/winter-squash"]
            }
          ]
        }
        """

    static let catalog = """
        {
          "meta": {"name": "cultivar-catalog", "version": "0.1.0", "provenance": "fixture catalog"},
          "cultivars": [
            {
              "cultivar": "Brandywine",
              "crop": "tomato",
              "data_origin": "shopify-tags",
              "days_to_maturity": {"raw": "60-90", "min": 60, "max": 90},
              "plant_spacing": "18 to 36 inches",
              "planting_season": ["Spring"],
              "sun": ["Full Sun"],
              "seed_type": ["Open Pollinated Seed", "Heirloom Seed"],
              "heirloom": null,
              "growth_habit": ["indeterminate"]
            },
            {
              "cultivar": "Brandywine",
              "crop": "tomato",
              "data_origin": "shopify-tags+prose",
              "days_to_maturity": {"raw": "80 days", "min": 80, "max": 80},
              "plant_spacing": null,
              "seed_type": ["Heirloom Seed"],
              "heirloom": true,
              "seed_prep": "Soaking"
            },
            {
              "cultivar": "Sungold Select",
              "crop": "tomato",
              "data_origin": "shopify-tags+prose",
              "days_to_maturity": {"raw": "57 days", "min": 57, "max": 57},
              "seed_type": ["Heirloom Seed", "Hybrid Seed"],
              "heirloom": false,
              "growth_habit": ["Leafy", "Pole"]
            },
            {
              "cultivar": "Marrow Mystery",
              "crop": "squash",
              "data_origin": "shopify-tags",
              "days_to_maturity": {"raw": "50 days", "min": 50, "max": 50}
            },
            {
              "cultivar": "Golden Zucchini",
              "crop": "squash",
              "data_origin": "shopify-tags"
            },
            {
              "cultivar": "Birdhouse Gourd",
              "crop": "squash",
              "data_origin": "shopify-tags"
            },
            {
              "cultivar": "Lovage",
              "crop": "other-herb",
              "data_origin": "shopify-tags"
            },
            {
              "cultivar": "Ronde de Nice",
              "crop": "summer-squash",
              "data_origin": "shopify-tags",
              "plant_spacing": "Plant crown at soil level",
              "seed_type": ["Open Pollinated Seed"]
            }
          ]
        }
        """

    static let pestDisease = """
        {
          "meta": {
            "name": "garden-pest-disease-cultivar-seed",
            "version": "0.3.0",
            "provenance": "fixture pests and diseases"
          },
          "pests": [
            {
              "id": "tomato-hornworm",
              "common_name": "Tomato hornworm",
              "scientific_name": "Manduca quinquemaculata",
              "hosts": ["tomato"],
              "biology": {"lifecycle": "one to two generations per year"},
              "damage": "defoliation",
              "identification": "large green caterpillar with a horn",
              "citations": ["https://example.org/hornworm"]
            },
            {
              "id": "green-peach-aphid",
              "common_name": "Green peach aphid",
              "scientific_name": "Myzus persicae",
              "hosts": ["tomato", "squash"],
              "vector_of": ["mosaic-virus"],
              "citations": ["https://example.org/aphid"]
            }
          ],
          "diseases": [
            {
              "id": "early-blight",
              "name": "Early blight",
              "pathogen": "Alternaria solani",
              "pathogen_type": "fungus",
              "hosts": ["tomato"],
              "symptoms": "target-ring leaf spots",
              "transmission": "splash-dispersed spores",
              "management": ["rotation", "mulch"],
              "citations": ["https://example.org/early-blight"]
            },
            {
              "id": "mosaic-virus",
              "name": "Mosaic virus",
              "pathogen": "Cucumber mosaic virus",
              "pathogen_type": "virus",
              "hosts": ["tomato", "squash"],
              "vectors": ["green-peach-aphid"],
              "citations": ["https://example.org/mosaic"]
            },
            {
              "id": "clubroot",
              "name": "Clubroot",
              "pathogen": "Plasmodiophora brassicae",
              "pathogen_type": "protist (plasmodiophorid)",
              "hosts": ["tomato"],
              "citations": ["https://example.org/clubroot"]
            }
          ],
          "cultivar_resistance_examples": [
            {
              "crop": "tomato",
              "cultivar": "Iron Lady",
              "resistances": ["early-blight"],
              "codes": "EB (HR)",
              "days_to_maturity": 75,
              "verification": "fixture verification note"
            },
            {
              "crop": "tomato",
              "cultivar": "Brandywine",
              "resistances": ["tomato-hornworm"],
              "codes": "HW"
            },
            {
              "crop": "squash",
              "cultivar": "Butternut Ultra",
              "resistances": ["early-blight"]
            },
            {
              "crop": "squash",
              "cultivar": "Ultra Nova",
              "resistances": ["early-blight"]
            }
          ]
        }
        """
}
