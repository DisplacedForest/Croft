import Foundation
import PlantCatalog
import Testing

@Suite struct PlantThreatNoteTests {
    @Test func aHostNoteWinsOverOrganismProse() throws {
        let fixture = try CatalogFixture(
            hornwormTomatoNote: "Strips leaves and scars green fruit high on the vine.")
        let page = try #require(try fixture.loader.page(for: .species(tomato.id)))
        let pest = try #require(page.threats.first { $0.name == "Tomato Hornworm" })
        #expect(pest.summary == "Strips leaves and scars green fruit high on the vine.")
        let disease = try #require(page.threats.first { $0.name == "Early Blight" })
        #expect(disease.summary == "Concentric leaf spots and stem lesions")
    }

    @Test func aCultivarPageInheritsTheHostNoteThroughItsSpecies() throws {
        let fixture = try CatalogFixture(
            hornwormTomatoNote: "Strips leaves and scars green fruit high on the vine.")
        let page = try #require(try fixture.loader.page(for: .cultivar(brandywine.id)))
        let pest = try #require(page.threats.first { $0.name == "Tomato Hornworm" })
        #expect(pest.summary == "Strips leaves and scars green fruit high on the vine.")
    }

    @Test func absentNotesFallBackToOrganismProse() throws {
        let fixture = try CatalogFixture()
        let page = try #require(try fixture.loader.page(for: .species(tomato.id)))
        let pest = try #require(page.threats.first { $0.name == "Tomato Hornworm" })
        #expect(pest.summary == "Defoliation and scarred fruit")
    }
}
