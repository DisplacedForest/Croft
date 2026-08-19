import Domain
import Foundation
import Persistence
import Testing

struct PlantDisplayNameTests {
    private func fixtures() throws -> (knowledge: AppDatabase, personal: AppDatabase) {
        (try AppDatabase.inMemory(), try AppDatabase.inMemory())
    }

    @Test func cultivarLeadsWithTheCropAndCarriesTheVarietal() throws {
        let (knowledge, personal) = try fixtures()
        let family = PlantFamily(name: "Apiaceae")
        let genus = Genus(familyID: family.id, name: "Daucus")
        try PlantFamilyRepository(personal).insert(family)
        try GenusRepository(personal).insert(genus)
        let species = Species(
            genusID: genus.id, scientificName: "Daucus carota", commonNames: ["carrot"])
        let nantes = Cultivar(speciesID: species.id, name: "Nantes")
        try SpeciesRepository(personal).insert(species)
        try CultivarRepository(personal).insert(nantes)

        let index = try PlantDisplayIndex(databases: [knowledge, personal])
        let display = index.display(for: .cultivar(nantes.id))
        #expect(display.title == "Carrot")
        #expect(display.varietal == "Nantes")
        #expect(display.detailName == "Nantes")
    }

    @Test func speciesOnlyShowsTheCropAlone() throws {
        let (knowledge, personal) = try fixtures()
        let family = PlantFamily(name: "Apiaceae")
        let genus = Genus(familyID: family.id, name: "Daucus")
        try PlantFamilyRepository(personal).insert(family)
        try GenusRepository(personal).insert(genus)
        let species = Species(
            genusID: genus.id, scientificName: "Daucus carota", commonNames: ["carrot"])
        try SpeciesRepository(personal).insert(species)

        let index = try PlantDisplayIndex(databases: [knowledge, personal])
        let display = index.display(for: .species(species.id))
        #expect(display.title == "Carrot")
        #expect(display.varietal == nil)
        #expect(display.detailName == "Carrot")
    }

    @Test func cultivarWithoutItsSpeciesDegradesToTheVarietalName() throws {
        let (knowledge, personal) = try fixtures()
        let family = PlantFamily(name: "Apiaceae")
        let genus = Genus(familyID: family.id, name: "Daucus")
        try PlantFamilyRepository(personal).insert(family)
        try GenusRepository(personal).insert(genus)
        let species = Species(
            genusID: genus.id, scientificName: "Daucus carota", commonNames: ["carrot"])
        let nantes = Cultivar(speciesID: species.id, name: "Nantes")
        try SpeciesRepository(personal).insert(species)
        try CultivarRepository(personal).insert(nantes)
        try personal.writer.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA foreign_keys = OFF")
            try db.execute(
                sql: "DELETE FROM species WHERE id = ?", arguments: [species.id.rawValue])
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        let index = try PlantDisplayIndex(databases: [knowledge, personal])
        let display = index.display(for: .cultivar(nantes.id))
        #expect(display.title == "Nantes")
        #expect(display.varietal == nil)
    }

    @Test func unknownIdentityStaysUnknown() throws {
        let (knowledge, personal) = try fixtures()
        let index = try PlantDisplayIndex(databases: [knowledge, personal])
        #expect(index.display(for: .species(.generate())).title == PlantDisplayIndex.unknownName)
        #expect(index.display(for: .cultivar(.generate())).title == PlantDisplayIndex.unknownName)
    }

    @Test func localizedCommonNamesFollowTheLocale() throws {
        let (knowledge, personal) = try fixtures()
        let family = PlantFamily(name: "Cucurbitaceae")
        let genus = Genus(familyID: family.id, name: "Cucurbita")
        try PlantFamilyRepository(personal).insert(family)
        try GenusRepository(personal).insert(genus)
        let species = Species(
            genusID: genus.id,
            scientificName: "Cucurbita pepo",
            commonNames: ["zucchini"],
            localizedCommonNames: [LocalizedPlantName(locale: "en-GB", name: "courgette")]
        )
        let cultivar = Cultivar(speciesID: species.id, name: "Black Beauty")
        try SpeciesRepository(personal).insert(species)
        try CultivarRepository(personal).insert(cultivar)

        let british = try PlantDisplayIndex(
            databases: [knowledge, personal], locale: Locale(identifier: "en_GB"))
        #expect(british.display(for: .cultivar(cultivar.id)).title == "Courgette")
        let american = try PlantDisplayIndex(
            databases: [knowledge, personal], locale: Locale(identifier: "en_US"))
        #expect(american.display(for: .cultivar(cultivar.id)).title == "Zucchini")
    }

    @Test func laterDatabasesOverrideEarlierOnes() throws {
        let (knowledge, personal) = try fixtures()
        let family = PlantFamily(name: "Apiaceae")
        let genus = Genus(familyID: family.id, name: "Daucus")
        for database in [knowledge, personal] {
            try PlantFamilyRepository(database).insert(family)
            try GenusRepository(database).insert(genus)
        }
        let species = Species(
            genusID: genus.id, scientificName: "Daucus carota", commonNames: ["carrot"])
        try SpeciesRepository(knowledge).insert(species)
        var renamed = species
        renamed.commonNames = ["heritage carrot"]
        try SpeciesRepository(personal).insert(renamed)

        let index = try PlantDisplayIndex(databases: [knowledge, personal])
        #expect(index.display(for: .species(species.id)).title == "Heritage carrot")
    }
}
