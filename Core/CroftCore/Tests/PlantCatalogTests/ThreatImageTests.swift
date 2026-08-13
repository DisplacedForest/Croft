import Foundation
import PlantCatalog
import Testing

@Suite struct PlantThreatImageTests {
    private func threat(_ fixture: CatalogFixture, named name: String) throws -> PlantThreat {
        let page = try #require(try fixture.loader.page(for: .species(tomato.id)))
        return try #require(page.threats.first { $0.name == name })
    }

    @Test func aThreatHasNoImageWhenTheSnapshotCarriesNone() throws {
        let fixture = try CatalogFixture()
        let hornworm = try threat(fixture, named: "Tomato Hornworm")
        #expect(hornworm.image == nil)
    }

    @Test func aThreatFallsBackToItsOrganismImage() throws {
        let fixture = try CatalogFixture()
        try fixture.insertImage(
            ownerKind: "pest", ownerID: hornworm.id.rawValue, file: "hornworm.jpg",
            kind: "organism")
        let found = try threat(fixture, named: "Tomato Hornworm")
        let image = try #require(found.image)
        #expect(image.file == "hornworm.jpg")
        #expect(image.artist == "A Photographer")
        #expect(image.sourcePageURL == "https://example.org/wiki/hornworm.jpg")
    }

    @Test func aHostPairImageWinsOverTheOrganismImage() throws {
        let fixture = try CatalogFixture()
        try fixture.insertImage(
            ownerKind: "pest", ownerID: hornworm.id.rawValue, file: "hornworm.jpg",
            kind: "organism")
        try fixture.insertImage(
            ownerKind: "pest", ownerID: hornworm.id.rawValue, file: "hornworm-tomato.jpg",
            kind: "damage", relatedID: tomato.id.rawValue)
        let found = try threat(fixture, named: "Tomato Hornworm")
        #expect(found.image?.file == "hornworm-tomato.jpg")
    }

    @Test func aPairImageForAnotherHostIsIgnored() throws {
        let fixture = try CatalogFixture()
        try fixture.insertImage(
            ownerKind: "pest", ownerID: hornworm.id.rawValue, file: "hornworm.jpg",
            kind: "organism")
        try fixture.insertImage(
            ownerKind: "pest", ownerID: hornworm.id.rawValue, file: "hornworm-basil.jpg",
            kind: "damage", relatedID: basil.id.rawValue)
        let found = try threat(fixture, named: "Tomato Hornworm")
        #expect(found.image?.file == "hornworm.jpg")
    }

    @Test func aPairImageAloneIsStillUsed() throws {
        let fixture = try CatalogFixture()
        try fixture.insertImage(
            ownerKind: "disease", ownerID: earlyBlight.id.rawValue,
            file: "early-blight-tomato.jpg", kind: "symptom", relatedID: tomato.id.rawValue)
        let found = try threat(fixture, named: "Early Blight")
        #expect(found.image?.file == "early-blight-tomato.jpg")
    }

    @Test func aCatalogImageOfTheHostIsNeverUsedForAThreat() throws {
        let fixture = try CatalogFixture()
        try fixture.insertImage(
            ownerKind: "species", ownerID: tomato.id.rawValue, file: "tomato.jpg")
        let found = try threat(fixture, named: "Tomato Hornworm")
        #expect(found.image == nil)
    }

    @Test func aCultivarPageResolvesThreatImagesThroughItsSpecies() throws {
        let fixture = try CatalogFixture()
        try fixture.insertImage(
            ownerKind: "pest", ownerID: hornworm.id.rawValue, file: "hornworm-tomato.jpg",
            kind: "damage", relatedID: tomato.id.rawValue)
        let page = try #require(try fixture.loader.page(for: .cultivar(brandywine.id)))
        let found = try #require(page.threats.first { $0.name == "Tomato Hornworm" })
        #expect(found.image?.file == "hornworm-tomato.jpg")
    }
}
