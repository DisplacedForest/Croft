import Domain
import Foundation
import GRDB
import Testing

@testable import Persistence

struct LocalizedCommonNameTests {
    private struct Seed {
        let database: AppDatabase
        let genus: Genus
        let species: SpeciesRepository
    }

    private func seed() throws -> Seed {
        let database = try AppDatabase.inMemory()
        let family = PlantFamily(name: "Solanaceae")
        let genus = Genus(familyID: family.id, name: "Solanum")
        try PlantFamilyRepository(database).insert(family)
        try GenusRepository(database).insert(genus)
        return Seed(database: database, genus: genus, species: SpeciesRepository(database))
    }

    @Test func localizedNamesRoundTripThroughTheSpeciesTable() throws {
        let seed = try seed()
        let species = Species(
            genusID: seed.genus.id,
            scientificName: "Solanum melongena",
            commonNames: ["eggplant"],
            localizedCommonNames: [LocalizedPlantName(locale: "en-GB", name: "aubergine")]
        )
        try seed.species.insert(species)
        let fetched = try #require(try seed.species.fetch(id: species.id))
        #expect(fetched == species)
        #expect(fetched.commonNames == ["eggplant"])
        #expect(
            fetched.localizedCommonNames == [LocalizedPlantName(locale: "en-GB", name: "aubergine")]
        )
    }

    @Test func legacyPlainNameArraysStillDecode() throws {
        let seed = try seed()
        let species = Species(
            genusID: seed.genus.id,
            scientificName: "Solanum tuberosum",
            commonNames: ["potato"]
        )
        try seed.species.insert(species)
        try seed.database.writer.write { db in
            try db.execute(
                sql: "UPDATE species SET common_names = ? WHERE id = ?",
                arguments: ["[\"potato\", \"spud\"]", species.id.rawValue]
            )
        }
        let fetched = try #require(try seed.species.fetch(id: species.id))
        #expect(fetched.commonNames == ["potato", "spud"])
        #expect(fetched.localizedCommonNames.isEmpty)
    }

    @Test func preferredNameResolvesByLanguageAndRegion() throws {
        let species = Species(
            genusID: Genus.ID(rawValue: "genus:solanum"),
            scientificName: "Solanum melongena",
            commonNames: ["eggplant"],
            localizedCommonNames: [LocalizedPlantName(locale: "en-GB", name: "aubergine")]
        )
        #expect(species.preferredCommonName(for: Locale(identifier: "en_GB")) == "aubergine")
        #expect(species.preferredCommonName(for: Locale(identifier: "en_US")) == "eggplant")
        #expect(species.preferredCommonName(for: Locale(identifier: "fr_FR")) == "eggplant")
        #expect(species.allCommonNames == ["eggplant", "aubergine"])
    }
}
