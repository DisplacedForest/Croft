import Domain
import Foundation
import Testing

@testable import PlantCatalog

@Suite struct CropCatalogTests {
    @Test func cropsGroupBySpeciesSortedByCommonName() throws {
        let fixture = try CatalogFixture()
        try fixture.createImageTable()
        let catalog = try fixture.loader.cropCatalog()
        #expect(catalog.crops.map(\.crop.displayName) == ["Basil", "Tomato"])
        let tomatoGroup = try #require(catalog.group(for: tomato.id))
        #expect(tomatoGroup.varietals.map(\.displayName) == ["Brandywine"])
        #expect(tomatoGroup.varietalCount == 1)
        let basilGroup = try #require(catalog.group(for: basil.id))
        #expect(basilGroup.varietals.isEmpty)
    }

    @Test func aCropWithoutACommonNameFallsBackToItsBinomial() throws {
        let fixture = try CatalogFixture()
        try fixture.createImageTable()
        let nameless = Species(genusID: solanum.id, scientificName: "Solanum zeta")
        try fixture.species.insert(nameless)
        let catalog = try fixture.loader.cropCatalog()
        let group = try #require(catalog.group(for: nameless.id))
        #expect(group.crop.displayName == "Solanum zeta")
    }

    @Test func varietalsFallBackToTheSpeciesImage() throws {
        let fixture = try CatalogFixture()
        try fixture.insertImage(
            ownerKind: "species", ownerID: tomato.id.rawValue, file: "tomato.jpg")
        let catalog = try fixture.loader.cropCatalog()
        let tomatoGroup = try #require(catalog.group(for: tomato.id))
        #expect(tomatoGroup.crop.imageFile == "tomato.jpg")
        #expect(tomatoGroup.varietals.first?.imageFile == "tomato.jpg")
    }

    @Test func aVarietalKeepsItsOwnImageWhenItHasOne() throws {
        let fixture = try CatalogFixture()
        try fixture.insertImage(
            ownerKind: "species", ownerID: tomato.id.rawValue, file: "tomato.jpg")
        try fixture.insertImage(
            ownerKind: "cultivar", ownerID: brandywine.id.rawValue, file: "brandywine.jpg")
        let catalog = try fixture.loader.cropCatalog()
        let tomatoGroup = try #require(catalog.group(for: tomato.id))
        #expect(tomatoGroup.varietals.first?.imageFile == "brandywine.jpg")
    }

    @Test func anEmptyQueryListsEveryCropAndNoVarietals() throws {
        let fixture = try CatalogFixture()
        try fixture.createImageTable()
        let catalog = try fixture.loader.cropCatalog()
        let results = CropSearch.filter(catalog, matching: "  ")
        #expect(results.crops.count == catalog.crops.count)
        #expect(results.varietals.isEmpty)
    }

    @Test func searchFindsACropByCommonNameWithoutFloodingVarietals() throws {
        let fixture = try CatalogFixture()
        try fixture.createImageTable()
        let catalog = try fixture.loader.cropCatalog()
        let results = CropSearch.filter(catalog, matching: "tomato")
        #expect(results.crops.map(\.crop.displayName) == ["Tomato"])
        #expect(results.varietals.isEmpty)
    }

    @Test func searchFindsACropByAlias() throws {
        let fixture = try CatalogFixture()
        try fixture.createImageTable()
        let catalog = try fixture.loader.cropCatalog()
        let results = CropSearch.filter(catalog, matching: "love apple")
        #expect(results.crops.map(\.crop.displayName) == ["Tomato"])
    }

    @Test func searchFindsAVarietalByItsOwnName() throws {
        let fixture = try CatalogFixture()
        try fixture.createImageTable()
        let catalog = try fixture.loader.cropCatalog()
        let results = CropSearch.filter(catalog, matching: "brandywine")
        #expect(results.crops.isEmpty)
        #expect(results.varietals.map(\.displayName) == ["Brandywine"])
    }

    @Test func searchFindsBothLevelsByBinomial() throws {
        let fixture = try CatalogFixture()
        try fixture.createImageTable()
        let catalog = try fixture.loader.cropCatalog()
        let results = CropSearch.filter(catalog, matching: "solanum lycopersicum")
        #expect(results.crops.map(\.crop.displayName) == ["Tomato"])
        #expect(results.varietals.map(\.displayName) == ["Brandywine"])
    }

    @Test func groupingReconcilesWithTheFlatCatalog() throws {
        let fixture = try CatalogFixture()
        try fixture.createImageTable()
        let extra = Cultivar(speciesID: basil.id, name: "Genovese")
        try fixture.cultivars.insert(extra)
        let catalog = try fixture.loader.cropCatalog()
        let flat = try fixture.loader.listItems()
        let flatCultivars = flat.filter { $0.kind == .cultivar }
        let groupedCultivarIDs = catalog.crops.flatMap(\.varietals).map(\.id).sorted()
        #expect(groupedCultivarIDs == flatCultivars.map(\.id).sorted())
        #expect(Set(groupedCultivarIDs).count == groupedCultivarIDs.count)
        #expect(catalog.crops.count == flat.count { $0.kind == .species })
    }
}
