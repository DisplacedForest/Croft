import Domain
import Testing

@testable import PlantCatalog

@Suite struct CropVarietalFilterTests {
    private func tomatoVarietals() throws -> [PlantListItem] {
        let fixture = try CatalogFixture()
        try fixture.createImageTable()
        let roma = Cultivar(speciesID: tomato.id, name: "Tomato - Roma")
        let gallo = Cultivar(
            speciesID: tomato.id, name: "Gallo Plum Tomato", commonNames: ["Pomodoro Gallo"])
        try fixture.cultivars.insert(roma)
        try fixture.cultivars.insert(gallo)
        let catalog = try fixture.loader.cropCatalog()
        let group = try #require(catalog.group(for: tomato.id))
        return group.varietals
    }

    @Test func anEmptyQueryKeepsTheFullList() throws {
        let varietals = try tomatoVarietals()
        #expect(PlantSearch.filter(varietals, matching: "  ") == varietals)
    }

    @Test func matchesTheBareVarietalName() throws {
        let varietals = try tomatoVarietals()
        #expect(PlantSearch.filter(varietals, matching: "roma").map(\.displayName) == ["Roma"])
    }

    @Test func matchesTheFullVendorName() throws {
        let varietals = try tomatoVarietals()
        #expect(
            PlantSearch.filter(varietals, matching: "Tomato - Roma").map(\.displayName)
                == ["Roma"])
    }

    @Test func matchesTheBinomial() throws {
        let varietals = try tomatoVarietals()
        let matched = PlantSearch.filter(varietals, matching: "Solanum lycopersicum")
        #expect(matched.count == varietals.count)
    }

    @Test func matchesAnAliasCaseAndDiacriticInsensitively() throws {
        let varietals = try tomatoVarietals()
        #expect(
            PlantSearch.filter(varietals, matching: "pomodoro gállo").map(\.displayName)
                == ["Gallo Plum Tomato"])
    }

    @Test func aMissMatchesNothing() throws {
        let varietals = try tomatoVarietals()
        #expect(PlantSearch.filter(varietals, matching: "courgette").isEmpty)
    }
}
