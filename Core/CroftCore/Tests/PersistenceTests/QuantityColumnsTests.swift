import Foundation
import GRDB
import Testing

import struct Domain.Quantity
import enum Domain.QuantityUnit

@testable import Persistence

private struct YieldRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "scratch_yield"

    var id: String
    var yieldAmount: Double
    var yieldUnit: String
    var noteAmount: Double?
    var noteUnit: String?

    enum CodingKeys: String, CodingKey {
        case id
        case yieldAmount = "yield_amount"
        case yieldUnit = "yield_unit"
        case noteAmount = "note_amount"
        case noteUnit = "note_unit"
    }
}

struct QuantityColumnsTests {
    private func scratchQueue() throws -> DatabaseQueue {
        let queue = try DatabaseQueue()
        try queue.write { db in
            try db.execute(
                sql: """
                    CREATE TABLE scratch_yield (
                        id TEXT PRIMARY KEY NOT NULL,
                        \(QuantityColumns.definitionSQL(named: "yield")),
                        \(QuantityColumns.definitionSQL(named: "note", optional: true))
                    )
                    """
            )
        }
        return queue
    }

    @Test func roundTripsThroughAScratchTable() throws {
        let queue = try scratchQueue()
        let yield = try Quantity(amount: 2.5, unit: .pound)
        let note = try Quantity(amount: 3, unit: .count)
        let encodedYield = QuantityColumns.encode(yield)
        let encodedNote = QuantityColumns.encode(note)
        try queue.write { db in
            try YieldRow(
                id: "row-1",
                yieldAmount: encodedYield.amount,
                yieldUnit: encodedYield.unit,
                noteAmount: encodedNote.amount,
                noteUnit: encodedNote.unit
            ).insert(db)
        }
        let fetched = try queue.read { db in
            try #require(try YieldRow.fetchOne(db, key: "row-1"))
        }
        #expect(
            try QuantityColumns.decode(amount: fetched.yieldAmount, unit: fetched.yieldUnit)
                == yield)
        #expect(
            try QuantityColumns.decodeOptional(amount: fetched.noteAmount, unit: fetched.noteUnit)
                == note)
    }

    @Test func encodeDecodeReencodeIsIdentity() throws {
        let fixtures = try QuantityUnit.allCases.flatMap { unit in
            try [0, 1, 3, 250, 1000].map { try Quantity(amount: Double($0), unit: unit) }
        }
        for quantity in fixtures {
            let encoded = QuantityColumns.encode(quantity)
            let decoded = try QuantityColumns.decode(amount: encoded.amount, unit: encoded.unit)
            #expect(decoded == quantity)
            let reencoded = QuantityColumns.encode(decoded)
            #expect(reencoded.amount == encoded.amount)
            #expect(reencoded.unit == encoded.unit)
        }
    }

    @Test func optionalColumnsRoundTripNil() throws {
        let queue = try scratchQueue()
        let yield = QuantityColumns.encode(try Quantity(amount: 500, unit: .milliliter))
        try queue.write { db in
            try YieldRow(
                id: "row-2",
                yieldAmount: yield.amount,
                yieldUnit: yield.unit,
                noteAmount: nil,
                noteUnit: nil
            ).insert(db)
        }
        let fetched = try queue.read { db in
            try #require(try YieldRow.fetchOne(db, key: "row-2"))
        }
        #expect(
            try QuantityColumns.decodeOptional(amount: fetched.noteAmount, unit: fetched.noteUnit)
                == nil)
    }

    @Test func decodeRejectsUnknownUnitsAndInvalidAmounts() {
        #expect(throws: QuantityColumnError.unknownUnit("cubit")) {
            try QuantityColumns.decode(amount: 1, unit: "cubit")
        }
        #expect(throws: QuantityColumnError.invalidAmount(-2)) {
            try QuantityColumns.decode(amount: -2, unit: "gram")
        }
        #expect(throws: QuantityColumnError.invalidAmount(1.5)) {
            try QuantityColumns.decode(amount: 1.5, unit: "count")
        }
        #expect(throws: QuantityColumnError.unpairedColumns) {
            try QuantityColumns.decodeOptional(amount: 4, unit: nil)
        }
        #expect(throws: QuantityColumnError.unpairedColumns) {
            try QuantityColumns.decodeOptional(amount: nil, unit: "gram")
        }
    }

    @Test func schemaEnforcesTheChecks() throws {
        let queue = try scratchQueue()
        try queue.write { db in
            #expect(throws: DatabaseError.self) {
                try db.execute(
                    sql: """
                        INSERT INTO scratch_yield (id, yield_amount, yield_unit)
                        VALUES ('bad-unit', 1, 'cubit')
                        """
                )
            }
            #expect(throws: DatabaseError.self) {
                try db.execute(
                    sql: """
                        INSERT INTO scratch_yield (id, yield_amount, yield_unit)
                        VALUES ('bad-amount', -1, 'gram')
                        """
                )
            }
            #expect(throws: DatabaseError.self) {
                try db.execute(
                    sql: """
                        INSERT INTO scratch_yield
                            (id, yield_amount, yield_unit, note_amount, note_unit)
                        VALUES ('bad-pair', 1, 'gram', 2, NULL)
                        """
                )
            }
        }
    }
}
