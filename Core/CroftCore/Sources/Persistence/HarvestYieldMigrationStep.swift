import GRDB

import enum Domain.QuantityUnit

extension SchemaMigrations {
    static let applyHarvestYield: @Sendable (Database) throws -> Void = { db in
        try createYieldHarvestTable(db)
        try copyHarvestRowsIntoYieldColumns(db)
        try db.execute(sql: "DROP TABLE harvest")
        try db.execute(sql: "ALTER TABLE harvest_new RENAME TO harvest")
        try db.execute(sql: "CREATE INDEX harvest_on_planting_id ON harvest(planting_id)")
    }

    private static func createYieldHarvestTable(_ db: Database) throws {
        let units = QuantityUnit.allCases
            .map { "'\($0.rawValue)'" }
            .joined(separator: ", ")
        try db.execute(
            sql: """
                CREATE TABLE harvest_new (
                    id TEXT PRIMARY KEY NOT NULL,
                    planting_id TEXT NOT NULL
                        REFERENCES planting(id) ON DELETE RESTRICT,
                    harvested_on DATETIME NOT NULL,
                    yield_amount REAL NOT NULL CHECK (yield_amount > 0),
                    yield_unit TEXT NOT NULL CHECK (
                        yield_unit IN (\(units), 'custom')
                    ),
                    yield_family TEXT CHECK (
                        yield_family IN ('mass', 'volume', 'count')
                    ),
                    custom_unit TEXT,
                    harvested_part TEXT CHECK (
                        harvested_part IN (
                            'leaf', 'stem', 'root', 'tuber',
                            'bulb', 'fruit', 'seed', 'flower'
                        )
                    ),
                    quality TEXT CHECK (
                        quality IN ('excellent', 'good', 'fair', 'poor')
                    ),
                    notes TEXT,
                    CHECK ((yield_unit = 'custom') = (custom_unit IS NOT NULL)),
                    CHECK ((yield_unit = 'custom') = (yield_family IS NULL))
                )
                """
        )
    }

    private static func copyHarvestRowsIntoYieldColumns(_ db: Database) throws {
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT id, planting_id, harvested_on, quantity, unit,
                       custom_unit, quality, notes
                FROM harvest
                """
        )
        for row in rows {
            let converted = convertLegacyYield(
                quantity: row["quantity"], unit: row["unit"], customUnit: row["custom_unit"])
            try db.execute(
                sql: """
                    INSERT INTO harvest_new
                        (id, planting_id, harvested_on, yield_amount, yield_unit,
                         yield_family, custom_unit, harvested_part, quality, notes)
                    VALUES
                        (:id, :planting_id, :harvested_on, :yield_amount, :yield_unit,
                         :yield_family, :custom_unit, NULL, :quality, :notes)
                    """,
                arguments: [
                    "id": row["id"] as DatabaseValue,
                    "planting_id": row["planting_id"] as DatabaseValue,
                    "harvested_on": row["harvested_on"] as DatabaseValue,
                    "yield_amount": converted.amount,
                    "yield_unit": converted.unit,
                    "yield_family": converted.family,
                    "custom_unit": converted.customUnit,
                    "quality": row["quality"] as DatabaseValue,
                    "notes": row["notes"] as DatabaseValue,
                ]
            )
        }
    }

    private struct ConvertedYield {
        let amount: Double
        let unit: String
        let family: String?
        let customUnit: String?
    }

    private static func convertLegacyYield(
        quantity: Double,
        unit: String,
        customUnit: String?
    ) -> ConvertedYield {
        let massUnits: [String: QuantityUnit] = [
            "gram": .gram, "kilogram": .kilogram, "ounce": .ounce, "pound": .pound,
        ]
        if let massUnit = massUnits[unit] {
            return ConvertedYield(
                amount: quantity * massUnit.canonicalFactor,
                unit: massUnit.rawValue,
                family: "mass",
                customUnit: nil
            )
        }
        if unit == "count" || unit == "bunch" {
            if quantity.truncatingRemainder(dividingBy: 1) == 0 {
                return ConvertedYield(
                    amount: quantity, unit: "count", family: "count", customUnit: nil)
            }
            return ConvertedYield(amount: quantity, unit: "custom", family: nil, customUnit: unit)
        }
        return ConvertedYield(amount: quantity, unit: "custom", family: nil, customUnit: customUnit)
    }
}
