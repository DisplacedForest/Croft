import Domain
import GRDB
import Graph
import Testing

@testable import Persistence

struct TaxonomyRegistrationTests {
    private struct Fixture {
        let database: AppDatabase
        let species: SpeciesRepository
        let cultivars: CultivarRepository
        let pests: PestRepository
        let tomato: Species
        let brandywine: Cultivar

        init() throws {
            database = try AppDatabase.inMemory()
            species = SpeciesRepository(database)
            cultivars = CultivarRepository(database)
            pests = PestRepository(database)
            let families = PlantFamilyRepository(database)
            let genera = GenusRepository(database)
            let family = PlantFamily(name: "Solanaceae")
            let genus = Genus(familyID: family.id, name: "Solanum")
            tomato = Species(genusID: genus.id, scientificName: "Solanum lycopersicum")
            brandywine = Cultivar(speciesID: tomato.id, name: "Brandywine")
            try families.insert(family)
            try genera.insert(genus)
            try species.insert(tomato)
            try cultivars.insert(brandywine)
        }

        func registered(_ id: String) throws -> EntityRef? {
            try database.writer.read { db in
                try GraphStore.registered(id, in: db)
            }
        }

        func edgeCount(referencing id: String) throws -> Int? {
            try database.writer.read { db in
                try Int.fetchOne(
                    db,
                    sql: """
                        SELECT COUNT(*) FROM relationship
                        WHERE from_entity_id = ? OR to_entity_id = ?
                        """,
                    arguments: [id, id]
                )
            }
        }
    }

    @Test func insertingASpeciesRegistersItAsAPlantEntity() throws {
        let fixture = try Fixture()
        #expect(try fixture.registered(fixture.tomato.id.rawValue)?.type == .plant)
    }

    @Test func insertingACultivarRegistersItAsAPlantEntity() throws {
        let fixture = try Fixture()
        #expect(try fixture.registered(fixture.brandywine.id.rawValue)?.type == .plant)
    }

    @Test func aRepositoryInsertedSpeciesTakesEdgesWithoutManualRegistration() throws {
        let fixture = try Fixture()
        let hornworm = Pest(commonName: "Tomato hornworm", organismType: .pest)
        try fixture.pests.insert(hornworm)
        let hosts = try fixture.database.writer.write { db -> [Edge] in
            try GraphStore.relate(
                from: EntityRef(id: fixture.tomato.id.rawValue, type: .plant),
                .hostOf,
                to: EntityRef(id: hornworm.id.rawValue, type: .pest),
                in: db
            )
            return try GraphStore.incoming(to: hornworm.id.rawValue, via: .hostOf, in: db)
        }
        #expect(hosts.map(\.source.id) == [fixture.tomato.id.rawValue])
    }

    @Test func aRepositoryInsertedCultivarTakesEdgesWithoutManualRegistration() throws {
        let fixture = try Fixture()
        let blight = Disease(name: "Early blight", pathogenType: .fungal)
        try DiseaseRepository(fixture.database).insert(blight)
        let sufferers = try fixture.database.writer.write { db -> [Edge] in
            try GraphStore.relate(
                from: EntityRef(id: fixture.brandywine.id.rawValue, type: .plant),
                .susceptibleTo,
                to: EntityRef(id: blight.id.rawValue, type: .disease),
                in: db
            )
            return try GraphStore.incoming(to: blight.id.rawValue, via: .susceptibleTo, in: db)
        }
        #expect(sufferers.map(\.source.id) == [fixture.brandywine.id.rawValue])
    }

    @Test func reimportingOverAnExistingRegistrationStaysIdempotent() throws {
        let fixture = try Fixture()
        try fixture.database.writer.write { db in
            try GraphStore.register(
                EntityRef(id: fixture.tomato.id.rawValue, type: .plant), in: db)
        }
        #expect(try fixture.registered(fixture.tomato.id.rawValue)?.type == .plant)
    }

    @Test func insertingASpeciesOverAForeignEntityTypeIsRejected() throws {
        let fixture = try Fixture()
        let ghost = Species(
            id: Species.ID(rawValue: "occupied"),
            genusID: fixture.tomato.genusID,
            scientificName: "Solanum occupatum"
        )
        try fixture.database.writer.write { db in
            try GraphStore.register(EntityRef(id: "occupied", type: .pest), in: db)
        }
        #expect(throws: GraphError.self) {
            try fixture.species.insert(ghost)
        }
    }

    @Test func deletingACultivarRemovesItsEntityAndEdges() throws {
        let fixture = try Fixture()
        let blight = Disease(name: "Early blight", pathogenType: .fungal)
        try DiseaseRepository(fixture.database).insert(blight)
        try fixture.database.writer.write { db in
            try GraphStore.relate(
                from: EntityRef(id: fixture.brandywine.id.rawValue, type: .plant),
                .susceptibleTo,
                to: EntityRef(id: blight.id.rawValue, type: .disease),
                in: db
            )
        }
        #expect(try fixture.cultivars.delete(id: fixture.brandywine.id))
        #expect(try fixture.registered(fixture.brandywine.id.rawValue) == nil)
        #expect(try fixture.edgeCount(referencing: fixture.brandywine.id.rawValue) == 0)
        #expect(try fixture.registered(blight.id.rawValue)?.type == .disease)
    }

    @Test func deletingAChildlessSpeciesRemovesItsEntity() throws {
        let fixture = try Fixture()
        try fixture.cultivars.delete(id: fixture.brandywine.id)
        #expect(try fixture.species.delete(id: fixture.tomato.id))
        #expect(try fixture.registered(fixture.tomato.id.rawValue) == nil)
    }

    @Test func aSpeciesWithCultivarsStillCannotBeDeleted() throws {
        let fixture = try Fixture()
        #expect(throws: DatabaseError.self) {
            try fixture.species.delete(id: fixture.tomato.id)
        }
        #expect(try fixture.registered(fixture.tomato.id.rawValue)?.type == .plant)
        #expect(try fixture.species.fetch(id: fixture.tomato.id) != nil)
    }
}
