import GRDB

import struct Domain.Quantity
import enum Domain.QuantityUnit

public enum QuantityColumnError: Error, Equatable, Sendable {
    case unknownUnit(String)
    case invalidAmount(Double)
    case unpairedColumns
}

public enum QuantityColumns {
    public static func amountColumn(named name: String) -> String {
        "\(name)_amount"
    }

    public static func unitColumn(named name: String) -> String {
        "\(name)_unit"
    }

    public static func definitionSQL(named name: String, optional: Bool = false) -> String {
        let amount = amountColumn(named: name)
        let unit = unitColumn(named: name)
        let units = QuantityUnit.allCases
            .map { "'\($0.rawValue)'" }
            .joined(separator: ", ")
        if optional {
            return """
                \(amount) REAL CHECK (\(amount) IS NULL OR \(amount) >= 0),
                \(unit) TEXT CHECK (\(unit) IS NULL OR \(unit) IN (\(units))),
                CHECK ((\(amount) IS NULL) = (\(unit) IS NULL))
                """
        }
        return """
            \(amount) REAL NOT NULL CHECK (\(amount) >= 0),
            \(unit) TEXT NOT NULL CHECK (\(unit) IN (\(units)))
            """
    }

    public static func encode(_ quantity: Quantity) -> (amount: Double, unit: String) {
        (quantity.canonicalAmount, quantity.unit.rawValue)
    }

    public static func decode(amount: Double, unit: String) throws -> Quantity {
        guard let decoded = QuantityUnit(rawValue: unit) else {
            throw QuantityColumnError.unknownUnit(unit)
        }
        do {
            return try Quantity(canonicalAmount: amount, unit: decoded)
        } catch {
            throw QuantityColumnError.invalidAmount(amount)
        }
    }

    public static func decodeOptional(amount: Double?, unit: String?) throws -> Quantity? {
        switch (amount, unit) {
        case (nil, nil):
            return nil
        case (.some(let amount), .some(let unit)):
            return try decode(amount: amount, unit: unit)
        default:
            throw QuantityColumnError.unpairedColumns
        }
    }
}
