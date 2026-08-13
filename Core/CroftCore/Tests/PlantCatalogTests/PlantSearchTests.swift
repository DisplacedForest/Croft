import Domain
import PlantCatalog
import Testing

@Suite struct PlantSearchTests {
    @Test func listItemsIncludeSpeciesAndCultivarsSortedByName() throws {
        let fixture = try CatalogFixture()
        let items = try fixture.loader.listItems()
        #expect(items.map(\.displayName) == ["Basil", "Brandywine", "Tomato"])
        let cultivar = try #require(items.first { $0.kind == .cultivar })
        #expect(cultivar.scientificName == "Solanum lycopersicum 'Brandywine'")
        #expect(cultivar.otherNames.contains("Tomato"))
    }

    @Test func searchMatchesCommonNameCaseInsensitively() throws {
        let fixture = try CatalogFixture()
        let items = try fixture.loader.listItems()
        let matches = PlantSearch.filter(items, matching: "tOmAtO")
        #expect(matches.map(\.displayName) == ["Brandywine", "Tomato"])
    }

    @Test func searchMatchesScientificName() throws {
        let fixture = try CatalogFixture()
        let items = try fixture.loader.listItems()
        let matches = PlantSearch.filter(items, matching: "ocimum")
        #expect(matches.map(\.displayName) == ["Basil"])
    }

    @Test func searchMatchesSecondaryCommonNames() throws {
        let fixture = try CatalogFixture()
        let items = try fixture.loader.listItems()
        let matches = PlantSearch.filter(items, matching: "love apple")
        #expect(matches.map(\.displayName) == ["Tomato"])
    }

    @Test func blankQueryReturnsEverything() throws {
        let fixture = try CatalogFixture()
        let items = try fixture.loader.listItems()
        #expect(PlantSearch.filter(items, matching: "   ") == items)
    }

    @Test func unmatchedQueryReturnsNothing() throws {
        let fixture = try CatalogFixture()
        let items = try fixture.loader.listItems()
        #expect(PlantSearch.filter(items, matching: "zucchini").isEmpty)
    }
}
