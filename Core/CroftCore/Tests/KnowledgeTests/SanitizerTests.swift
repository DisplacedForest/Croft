import Foundation
import Testing

@testable import Knowledge

struct SanitizerTests {
    private let raw = """
        {
          "meta": {
            "name": "cultivar-catalog",
            "version": "0.1.0",
            "counts_by_vendor": {"edenbrothers": 1},
            "coverage_pct": {"flavor_profile": 47, "days_to_maturity": 94.2}
          },
          "cultivars": [
            {
              "cultivar": "Lovage",
              "crop": "other-herb",
              "vendor": "edenbrothers",
              "price": 3.5,
              "flavor_profile": "bold celery",
              "url": "https://vendor.example/lovage",
              "image_url": "https://cdn.example/lovage.jpg",
              "image_file": "lovage.jpg",
              "image_shared": false,
              "days_to_maturity": {"raw": "90", "min": 90, "max": 90},
              "data_origin": "shopify-tags"
            },
            {
              "cultivar": "Brandywine",
              "crop": "tomato",
              "vendor": "migardener",
              "price": 2,
              "data_origin": "shopify-tags+prose"
            }
          ]
        }
        """

    @Test func strippedFieldsNeverSurviveSanitization() throws {
        let sanitized = try CatalogSanitizer.sanitize(rawCatalog: Data(raw.utf8))
        let text = try #require(String(data: sanitized, encoding: .utf8))
        for field in CatalogSanitizer.strippedFields {
            #expect(!text.contains("\"\(field)\""))
        }
        #expect(!text.contains("vendor.example"))
        #expect(!text.contains("cdn.example"))
        #expect(text.contains("\"days_to_maturity\""))
    }

    @Test func sanitizationIsDeterministicAndIdempotent() throws {
        let first = try CatalogSanitizer.sanitize(rawCatalog: Data(raw.utf8))
        let second = try CatalogSanitizer.sanitize(rawCatalog: Data(raw.utf8))
        #expect(first == second)
        let resanitized = try CatalogSanitizer.sanitize(rawCatalog: first)
        #expect(resanitized == first)
    }

    @Test func rowsAreSortedByCropAndCultivar() throws {
        let sanitized = try CatalogSanitizer.sanitize(rawCatalog: Data(raw.utf8))
        let decoded = try JSONSerialization.jsonObject(with: sanitized) as? [String: Any]
        let rows = try #require(decoded?["cultivars"] as? [[String: Any]])
        #expect(rows.map { $0["crop"] as? String } == ["other-herb", "tomato"])
    }

    @Test func pestDiseaseSanitizationScrubsNestedVendorFields() throws {
        let raw = """
            {
              "meta": {"name": "pests", "version": "0.1.0"},
              "pests": [],
              "diseases": [],
              "cultivar_resistance_examples": [
                {
                  "crop": "tomato",
                  "cultivar": "Defiant PhR",
                  "resistances": ["late-blight"],
                  "image_file": "tomato_defiant.jpg",
                  "image_url": "https://cdn.example/defiant.jpg",
                  "image_shared": false,
                  "growing": {"url": "https://vendor.example/defiant"}
                }
              ]
            }
            """
        let sanitized = try CatalogSanitizer.sanitize(rawPestDisease: Data(raw.utf8))
        let text = try #require(String(data: sanitized, encoding: .utf8))
        for field in CatalogSanitizer.strippedFields {
            #expect(!text.contains("\"\(field)\""))
        }
        #expect(!text.contains("cdn.example"))
        #expect(!text.contains("vendor.example"))
        #expect(text.contains("\"cultivar\" : \"Defiant PhR\""))
        #expect(text.contains("late-blight"))
        let again = try CatalogSanitizer.sanitize(rawPestDisease: sanitized)
        #expect(again == sanitized)
    }

    @Test func aNonObjectCatalogIsRejected() {
        #expect(throws: SanitizerError.self) {
            try CatalogSanitizer.sanitize(rawCatalog: Data("[1,2]".utf8))
        }
    }
}
