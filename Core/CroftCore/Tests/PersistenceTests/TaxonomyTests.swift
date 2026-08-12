import Domain
import GRDB
import Testing

@testable import Persistence

private struct TaxonomyContext {
    let database: AppDatabase
    let families: PlantFamilyRepository
    let genera: GenusRepository
    let species: SpeciesRepository
    let cultivars: CultivarRepository

    init() throws {
        database = try AppDatabase.inMemory()
        families = PlantFamilyRepository(database)
        genera = GenusRepository(database)
        species = SpeciesRepository(database)
        cultivars = CultivarRepository(database)
    }
}

private func makeFamily() -> PlantFamily {
    PlantFamily(name: "Solanaceae", commonNames: ["nightshade", "potato family"])
}

private func makeGenus(in family: PlantFamily) -> Genus {
    Genus(familyID: family.id, name: "Solanum")
}

private func makeSpecies(in genus: Genus) -> Species {
    Species(
        genusID: genus.id,
        scientificName: "Solanum lycopersicum",
        commonNames: ["tomato", "love apple"],
        lifeCycle: .annual,
        growthHabit: .vine,
        sunExposure: .fullSun,
        waterNeed: .moderate,
        soilPH: 6.0...6.8,
        spacingCentimeters: 45.0...60.0,
        daysToMaturity: 60...85,
        hardinessZones: 2...11,
        harvestableParts: [.fruit, .seed]
    )
}

private func makeCultivar(of species: Species) -> Cultivar {
    Cultivar(
        speciesID: species.id,
        name: "Brandywine",
        commonNames: ["brandywine tomato"],
        daysToMaturity: 80...100,
        spacingCentimeters: 60.0...90.0,
        growthHabit: .vine
    )
}

struct PlantFamilyRepositoryTests {
    @Test func insertedFamilyRoundTrips() throws {
        let context = try TaxonomyContext()
        let family = makeFamily()
        try context.families.insert(family)
        #expect(try context.families.fetch(id: family.id) == family)
        #expect(try context.families.fetchAll() == [family])
    }

    @Test func updatedFamilyIsPersisted() throws {
        let context = try TaxonomyContext()
        var family = makeFamily()
        try context.families.insert(family)
        family.name = "Brassicaceae"
        family.commonNames = ["mustard family"]
        try context.families.update(family)
        #expect(try context.families.fetch(id: family.id) == family)
    }

    @Test func deletedFamilyIsGone() throws {
        let context = try TaxonomyContext()
        let family = makeFamily()
        try context.families.insert(family)
        #expect(try context.families.delete(id: family.id))
        #expect(try context.families.fetch(id: family.id) == nil)
        #expect(try context.families.fetchAll().isEmpty)
    }
}

struct GenusRepositoryTests {
    @Test func insertedGenusRoundTrips() throws {
        let context = try TaxonomyContext()
        let family = makeFamily()
        let genus = makeGenus(in: family)
        try context.families.insert(family)
        try context.genera.insert(genus)
        #expect(try context.genera.fetch(id: genus.id) == genus)
        #expect(try context.genera.genera(inFamily: family.id) == [genus])
    }

    @Test func updatedGenusIsPersisted() throws {
        let context = try TaxonomyContext()
        let family = makeFamily()
        var genus = makeGenus(in: family)
        try context.families.insert(family)
        try context.genera.insert(genus)
        genus.name = "Capsicum"
        try context.genera.update(genus)
        #expect(try context.genera.fetch(id: genus.id) == genus)
    }

    @Test func deletedGenusIsGone() throws {
        let context = try TaxonomyContext()
        let family = makeFamily()
        let genus = makeGenus(in: family)
        try context.families.insert(family)
        try context.genera.insert(genus)
        #expect(try context.genera.delete(id: genus.id))
        #expect(try context.genera.fetchAll().isEmpty)
    }

    @Test func generaAreScopedToTheirFamily() throws {
        let context = try TaxonomyContext()
        let family = makeFamily()
        let other = PlantFamily(name: "Apiaceae")
        try context.families.insert(family)
        try context.families.insert(other)
        let genus = makeGenus(in: family)
        try context.genera.insert(genus)
        try context.genera.insert(Genus(familyID: other.id, name: "Daucus"))
        #expect(try context.genera.genera(inFamily: family.id) == [genus])
        #expect(try context.genera.fetchAll().count == 2)
    }
}

struct SpeciesRepositoryTests {
    @Test func insertedSpeciesRoundTripsWithEveryAttribute() throws {
        let context = try TaxonomyContext()
        let family = makeFamily()
        let genus = makeGenus(in: family)
        let species = makeSpecies(in: genus)
        try context.families.insert(family)
        try context.genera.insert(genus)
        try context.species.insert(species)
        #expect(try context.species.fetch(id: species.id) == species)
        #expect(try context.species.species(inGenus: genus.id) == [species])
    }

    @Test func updatedSpeciesIsPersisted() throws {
        let context = try TaxonomyContext()
        let family = makeFamily()
        let genus = makeGenus(in: family)
        var species = makeSpecies(in: genus)
        try context.families.insert(family)
        try context.genera.insert(genus)
        try context.species.insert(species)
        species.scientificName = "Solanum tuberosum"
        species.growthHabit = .sprawling
        species.harvestableParts = [.tuber]
        species.soilPH = nil
        species.daysToMaturity = 90...120
        try context.species.update(species)
        #expect(try context.species.fetch(id: species.id) == species)
    }

    @Test func deletedSpeciesIsGone() throws {
        let context = try TaxonomyContext()
        let family = makeFamily()
        let genus = makeGenus(in: family)
        let species = makeSpecies(in: genus)
        try context.families.insert(family)
        try context.genera.insert(genus)
        try context.species.insert(species)
        #expect(try context.species.delete(id: species.id))
        #expect(try context.species.fetchAll().isEmpty)
    }
}

struct CultivarRepositoryTests {
    @Test func insertedCultivarRoundTrips() throws {
        let context = try TaxonomyContext()
        let family = makeFamily()
        let genus = makeGenus(in: family)
        let species = makeSpecies(in: genus)
        let cultivar = makeCultivar(of: species)
        try context.families.insert(family)
        try context.genera.insert(genus)
        try context.species.insert(species)
        try context.cultivars.insert(cultivar)
        #expect(try context.cultivars.fetch(id: cultivar.id) == cultivar)
        #expect(try context.cultivars.cultivars(ofSpecies: species.id) == [cultivar])
    }

    @Test func updatedCultivarIsPersisted() throws {
        let context = try TaxonomyContext()
        let family = makeFamily()
        let genus = makeGenus(in: family)
        let species = makeSpecies(in: genus)
        var cultivar = makeCultivar(of: species)
        try context.families.insert(family)
        try context.genera.insert(genus)
        try context.species.insert(species)
        try context.cultivars.insert(cultivar)
        cultivar.name = "Cherokee Purple"
        cultivar.growthHabit = nil
        cultivar.spacingCentimeters = nil
        try context.cultivars.update(cultivar)
        #expect(try context.cultivars.fetch(id: cultivar.id) == cultivar)
    }

    @Test func deletedCultivarIsGone() throws {
        let context = try TaxonomyContext()
        let family = makeFamily()
        let genus = makeGenus(in: family)
        let species = makeSpecies(in: genus)
        let cultivar = makeCultivar(of: species)
        try context.families.insert(family)
        try context.genera.insert(genus)
        try context.species.insert(species)
        try context.cultivars.insert(cultivar)
        #expect(try context.cultivars.delete(id: cultivar.id))
        #expect(try context.cultivars.fetchAll().isEmpty)
    }
}

struct TaxonomyHierarchyTests {
    @Test func genusWithoutFamilyIsRejected() throws {
        let context = try TaxonomyContext()
        #expect(throws: DatabaseError.self) {
            try context.genera.insert(Genus(familyID: .generate(), name: "Orphan"))
        }
    }

    @Test func speciesWithoutGenusIsRejected() throws {
        let context = try TaxonomyContext()
        #expect(throws: DatabaseError.self) {
            try context.species.insert(
                Species(genusID: .generate(), scientificName: "Orphan orphan")
            )
        }
    }

    @Test func cultivarWithoutSpeciesIsRejected() throws {
        let context = try TaxonomyContext()
        #expect(throws: DatabaseError.self) {
            try context.cultivars.insert(Cultivar(speciesID: .generate(), name: "Orphan"))
        }
    }

    @Test func familyWithGeneraCannotBeDeleted() throws {
        let context = try TaxonomyContext()
        let family = makeFamily()
        let genus = makeGenus(in: family)
        try context.families.insert(family)
        try context.genera.insert(genus)
        #expect(throws: DatabaseError.self) {
            try context.families.delete(id: family.id)
        }
        #expect(try context.genera.delete(id: genus.id))
        #expect(try context.families.delete(id: family.id))
    }

    @Test func genusWithSpeciesCannotBeDeleted() throws {
        let context = try TaxonomyContext()
        let family = makeFamily()
        let genus = makeGenus(in: family)
        let species = makeSpecies(in: genus)
        try context.families.insert(family)
        try context.genera.insert(genus)
        try context.species.insert(species)
        #expect(throws: DatabaseError.self) {
            try context.genera.delete(id: genus.id)
        }
        #expect(try context.species.delete(id: species.id))
        #expect(try context.genera.delete(id: genus.id))
    }

    @Test func speciesWithCultivarsCannotBeDeleted() throws {
        let context = try TaxonomyContext()
        let family = makeFamily()
        let genus = makeGenus(in: family)
        let species = makeSpecies(in: genus)
        let cultivar = makeCultivar(of: species)
        try context.families.insert(family)
        try context.genera.insert(genus)
        try context.species.insert(species)
        try context.cultivars.insert(cultivar)
        #expect(throws: DatabaseError.self) {
            try context.species.delete(id: species.id)
        }
        #expect(try context.cultivars.delete(id: cultivar.id))
        #expect(try context.species.delete(id: species.id))
    }
}
