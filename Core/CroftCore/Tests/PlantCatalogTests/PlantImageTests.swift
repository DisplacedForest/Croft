import Foundation
import PlantCatalog
import Testing

@Suite struct PlantImageTests {
    @Test func aPageHasNoImageWhenTheSnapshotCarriesNone() throws {
        let fixture = try CatalogFixture()
        let page = try #require(try fixture.loader.page(for: .species(tomato.id)))
        #expect(page.image == nil)
        let items = try fixture.loader.listItems()
        #expect(items.allSatisfy { $0.imageFile == nil })
    }

    @Test func anEmptyImageTableStillResolvesToNoImage() throws {
        let fixture = try CatalogFixture()
        try fixture.createImageTable()
        let page = try #require(try fixture.loader.page(for: .species(tomato.id)))
        #expect(page.image == nil)
    }

    @Test func aSpeciesPageResolvesItsOwnImage() throws {
        let fixture = try CatalogFixture()
        try fixture.insertImage(
            ownerKind: "species", ownerID: tomato.id.rawValue, file: "tomato.jpg")
        let page = try #require(try fixture.loader.page(for: .species(tomato.id)))
        let image = try #require(page.image)
        #expect(image.file == "tomato.jpg")
        #expect(image.license == "CC BY 2.0")
        #expect(image.licenseURL == "https://creativecommons.org/licenses/by/2.0/")
        #expect(image.artist == "A Photographer")
        #expect(image.sourcePageURL == "https://example.org/wiki/tomato.jpg")
    }

    @Test func aCultivarPageFallsBackToTheSpeciesImage() throws {
        let fixture = try CatalogFixture()
        try fixture.insertImage(
            ownerKind: "species", ownerID: tomato.id.rawValue, file: "tomato.jpg")
        let page = try #require(try fixture.loader.page(for: .cultivar(brandywine.id)))
        #expect(page.image?.file == "tomato.jpg")
    }

    @Test func aCultivarPagePrefersItsOwnImage() throws {
        let fixture = try CatalogFixture()
        try fixture.insertImage(
            ownerKind: "species", ownerID: tomato.id.rawValue, file: "tomato.jpg")
        try fixture.insertImage(
            ownerKind: "cultivar", ownerID: brandywine.id.rawValue, file: "brandywine.jpg",
            license: "CC0", licenseURL: nil, artist: nil)
        let page = try #require(try fixture.loader.page(for: .cultivar(brandywine.id)))
        let image = try #require(page.image)
        #expect(image.file == "brandywine.jpg")
        #expect(image.licenseURL == nil)
        #expect(image.artist == nil)
    }

    @Test func listRowsCarryTheFileNameWithCultivarFallback() throws {
        let fixture = try CatalogFixture()
        try fixture.insertImage(
            ownerKind: "species", ownerID: tomato.id.rawValue, file: "tomato.jpg")
        let items = try fixture.loader.listItems()
        let files = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.imageFile) })
        #expect(files[tomato.id.rawValue] == "tomato.jpg")
        #expect(files[brandywine.id.rawValue] == "tomato.jpg")
        #expect(files[basil.id.rawValue] == .some(nil))
    }

    @Test func imagesOfAnotherKindAreIgnored() throws {
        let fixture = try CatalogFixture()
        try fixture.insertImage(
            ownerKind: "species", ownerID: tomato.id.rawValue, file: "tomato-leaf.jpg",
            kind: "detail")
        let page = try #require(try fixture.loader.page(for: .species(tomato.id)))
        #expect(page.image == nil)
    }
}
