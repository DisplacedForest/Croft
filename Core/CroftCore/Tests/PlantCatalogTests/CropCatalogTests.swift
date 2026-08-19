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

    @Test func varietalRowsDropTheRedundantCropPrefix() throws {
        let fixture = try CatalogFixture()
        try fixture.createImageTable()
        let roma = Cultivar(speciesID: tomato.id, name: "Tomato - Roma")
        let organicRoma = Cultivar(speciesID: tomato.id, name: "Tomato (Organic) - Roma")
        try fixture.cultivars.insert(roma)
        try fixture.cultivars.insert(organicRoma)
        let catalog = try fixture.loader.cropCatalog()
        let tomatoGroup = try #require(catalog.group(for: tomato.id))
        #expect(
            tomatoGroup.varietals.map(\.displayName)
                == ["Brandywine", "Roma", "Roma (Organic)"])
    }

    @Test func varietalBinomialsQuoteTheBareName() throws {
        let fixture = try CatalogFixture()
        try fixture.createImageTable()
        let roma = Cultivar(speciesID: tomato.id, name: "Tomato - Roma")
        try fixture.cultivars.insert(roma)
        let catalog = try fixture.loader.cropCatalog()
        let tomatoGroup = try #require(catalog.group(for: tomato.id))
        let row = try #require(tomatoGroup.varietals.first { $0.id == roma.id.rawValue })
        #expect(row.scientificName == "Solanum lycopersicum 'Roma'")
    }

    @Test func searchStillFindsAVarietalByItsFullVendorName() throws {
        let fixture = try CatalogFixture()
        try fixture.createImageTable()
        let roma = Cultivar(speciesID: tomato.id, name: "Tomato - Roma")
        try fixture.cultivars.insert(roma)
        let catalog = try fixture.loader.cropCatalog()
        let byVendorName = CropSearch.filter(catalog, matching: "Tomato - Roma")
        #expect(byVendorName.varietals.map(\.id) == [roma.id.rawValue])
        let byBareName = CropSearch.filter(catalog, matching: "roma")
        #expect(byBareName.varietals.map(\.id) == [roma.id.rawValue])
    }

    @Test func anUnprefixedVarietalKeepsItsNameAndGainsNoAlias() throws {
        let fixture = try CatalogFixture()
        try fixture.createImageTable()
        let catalog = try fixture.loader.cropCatalog()
        let tomatoGroup = try #require(catalog.group(for: tomato.id))
        let row = try #require(tomatoGroup.varietals.first)
        #expect(row.displayName == "Brandywine")
        #expect(row.otherNames.isEmpty)
    }

    @Test func collidingBareNamesFallBackToTheirStoredNames() throws {
        let fixture = try CatalogFixture()
        try fixture.createImageTable()
        let bare = Cultivar(speciesID: tomato.id, name: "Big Beef Plus")
        let prefixed = Cultivar(speciesID: tomato.id, name: "Tomato - Big Beef Plus")
        try fixture.cultivars.insert(bare)
        try fixture.cultivars.insert(prefixed)
        let catalog = try fixture.loader.cropCatalog()
        let tomatoGroup = try #require(catalog.group(for: tomato.id))
        #expect(
            tomatoGroup.varietals.map(\.displayName)
                == ["Big Beef Plus", "Brandywine", "Tomato - Big Beef Plus"])
    }

    @Test func theDetailPageUsesTheBareNameForTitleAndTaxonomy() throws {
        let fixture = try CatalogFixture()
        try fixture.createImageTable()
        let roma = Cultivar(speciesID: tomato.id, name: "Tomato - Roma")
        try fixture.cultivars.insert(roma)
        let page = try #require(try fixture.loader.page(for: .cultivar(roma.id)))
        #expect(page.displayName == "Roma")
        #expect(page.taxonomy.cultivarName == "Roma")
    }

    @Test func aCollidingDetailPageKeepsTheStoredName() throws {
        let fixture = try CatalogFixture()
        try fixture.createImageTable()
        let bare = Cultivar(speciesID: tomato.id, name: "Crimson Sweet")
        let prefixed = Cultivar(speciesID: tomato.id, name: "Tomato - Crimson Sweet")
        try fixture.cultivars.insert(bare)
        try fixture.cultivars.insert(prefixed)
        let page = try #require(try fixture.loader.page(for: .cultivar(prefixed.id)))
        #expect(page.displayName == "Tomato - Crimson Sweet")
    }
}
