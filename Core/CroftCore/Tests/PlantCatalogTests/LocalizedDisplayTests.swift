import Domain
import Foundation
import Testing

@testable import PlantCatalog

@Suite struct LocalizedDisplayTests {
    private func seed() throws -> CatalogFixture {
        let fixture = try CatalogFixture()
        try fixture.createImageTable()
        let aubergine = Species(
            genusID: solanum.id,
            scientificName: "Solanum melongena",
            commonNames: ["eggplant"],
            localizedCommonNames: [LocalizedPlantName(locale: "en-GB", name: "aubergine")]
        )
        try fixture.species.insert(aubergine)
        return fixture
    }

    private func loader(_ fixture: CatalogFixture, locale: String) -> PlantPageLoader {
        PlantPageLoader(fixture.database, locale: Locale(identifier: locale))
    }

    @Test func britishSystemsSeeTheBritishNameFirst() throws {
        let fixture = try seed()
        let catalog = try loader(fixture, locale: "en_GB").cropCatalog()
        let names = catalog.crops.map(\.crop.displayName)
        #expect(names.contains("Aubergine"))
        #expect(!names.contains("Eggplant"))
    }

    @Test func americanSystemsAreUnchanged() throws {
        let fixture = try seed()
        let catalog = try loader(fixture, locale: "en_US").cropCatalog()
        let names = catalog.crops.map(\.crop.displayName)
        #expect(names.contains("Eggplant"))
        #expect(!names.contains("Aubergine"))
    }

    @Test func eitherNameFindsTheCropOnAnyLocale() throws {
        let fixture = try seed()
        for locale in ["en_GB", "en_US", "de_DE"] {
            let catalog = try loader(fixture, locale: locale).cropCatalog()
            for query in ["aubergine", "eggplant"] {
                let results = CropSearch.filter(catalog, matching: query)
                #expect(
                    results.crops.count == 1,
                    "query \(query) under \(locale) found \(results.crops.count)")
            }
        }
    }

    @Test func theFlatListAndPickersResolveTheSameWay() throws {
        let fixture = try seed()
        let british = try loader(fixture, locale: "en_GB").listItems()
        let item = try #require(
            british.first { $0.scientificName == "Solanum melongena" && $0.kind == .species })
        #expect(item.displayName == "Aubergine")
        #expect(item.otherNames.contains("eggplant"))
        let american = try loader(fixture, locale: "en_US").listItems()
        let usItem = try #require(
            american.first { $0.scientificName == "Solanum melongena" && $0.kind == .species })
        #expect(usItem.displayName == "Eggplant")
        #expect(usItem.otherNames.contains("aubergine"))
    }
}
