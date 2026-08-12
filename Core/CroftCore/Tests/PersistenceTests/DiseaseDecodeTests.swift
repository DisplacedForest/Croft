import Domain
import GRDB
import Testing

@testable import Persistence

private struct CorruptibleDisease {
    let database: AppDatabase
    let disease: Disease

    init() throws {
        database = try AppDatabase.inMemory()
        disease = Disease(name: "Early Blight", pathogenType: .fungal)
        try DiseaseRepository(database).insert(disease)
    }

    func corrupt(_ assignments: String) throws {
        try database.writer.write { db in
            try db.execute(sql: "PRAGMA ignore_check_constraints = ON")
            try db.execute(
                sql: "UPDATE disease SET \(assignments) WHERE id = ?",
                arguments: [disease.id.rawValue]
            )
            try db.execute(sql: "PRAGMA ignore_check_constraints = OFF")
        }
    }
}

struct DiseaseDecodeTests {
    @Test func unknownPathogenTypeRawValueFailsFetch() throws {
        let context = try CorruptibleDisease()
        try context.corrupt("pathogen_type = 'bogus'")
        #expect(
            throws: TaxonomyCodingError.unknownRawValue(
                table: "disease",
                column: "pathogen_type",
                value: "bogus"
            )
        ) {
            try DiseaseRepository(context.database).fetch(id: context.disease.id)
        }
    }

    @Test func unknownAffectedPlantPartFailsFetch() throws {
        let context = try CorruptibleDisease()
        try context.corrupt(#"affected_plant_parts = '["leaf","bogus"]'"#)
        #expect(
            throws: TaxonomyCodingError.unknownRawValue(
                table: "disease",
                column: "affected_plant_parts",
                value: "bogus"
            )
        ) {
            try DiseaseRepository(context.database).fetch(id: context.disease.id)
        }
    }

    @Test func corruptRowFailsEveryDiseaseFetchPath() throws {
        let context = try CorruptibleDisease()
        try context.corrupt("pathogen_type = 'bogus'")
        let repository = DiseaseRepository(context.database)
        let expected = TaxonomyCodingError.unknownRawValue(
            table: "disease",
            column: "pathogen_type",
            value: "bogus"
        )
        #expect(throws: expected) { try repository.fetchAll() }
    }

    @Test func nullAndDefaultColumnsStillDecode() throws {
        let context = try CorruptibleDisease()
        let fetched = try #require(
            try DiseaseRepository(context.database).fetch(id: context.disease.id)
        )
        #expect(fetched.pathogen == nil)
        #expect(fetched.symptoms == nil)
        #expect(fetched.transmission == nil)
        #expect(fetched.affectedPlantParts.isEmpty)
        #expect(fetched.prevention.isEmpty)
        #expect(fetched.management.isEmpty)
    }

    @Test func allPathogenTypeCasesRoundTripThroughStorage() throws {
        let context = try CorruptibleDisease()
        let repository = DiseaseRepository(context.database)
        for pathogenType in PathogenType.allCases {
            var disease = context.disease
            disease.pathogenType = pathogenType
            try repository.update(disease)
            let fetched = try #require(try repository.fetch(id: disease.id))
            #expect(fetched.pathogenType == pathogenType)
        }
    }
}
