import Foundation

public enum UnitFamily: String, CaseIterable, Codable, Hashable, Sendable {
    case mass
    case volume
    case count
}

public enum UnitSystem: String, CaseIterable, Codable, Hashable, Sendable {
    case metric
    case imperial
}

public enum QuantityUnit: String, CaseIterable, Codable, Hashable, Sendable {
    case gram
    case kilogram
    case ounce
    case pound
    case milliliter
    case liter
    case fluidOunce = "fluid_ounce"
    case cup
    case pint
    case quart
    case gallon
    case count

    public var family: UnitFamily {
        switch self {
        case .gram, .kilogram, .ounce, .pound:
            .mass
        case .milliliter, .liter, .fluidOunce, .cup, .pint, .quart, .gallon:
            .volume
        case .count:
            .count
        }
    }

    public var system: UnitSystem? {
        switch self {
        case .gram, .kilogram, .milliliter, .liter:
            .metric
        case .ounce, .pound, .fluidOunce, .cup, .pint, .quart, .gallon:
            .imperial
        case .count:
            nil
        }
    }

    public var canonicalFactor: Double {
        switch self {
        case .gram: 1
        case .kilogram: 1000
        case .ounce: 28.349_523_125
        case .pound: 453.592_37
        case .milliliter: 1
        case .liter: 1000
        case .fluidOunce: 29.573_529_562_5
        case .cup: 236.588_236_5
        case .pint: 473.176_473
        case .quart: 946.352_946
        case .gallon: 3785.411_784
        case .count: 1
        }
    }

    public var symbol: String {
        switch self {
        case .gram: "g"
        case .kilogram: "kg"
        case .ounce: "oz"
        case .pound: "lb"
        case .milliliter: "mL"
        case .liter: "L"
        case .fluidOunce: "fl oz"
        case .cup: "cup"
        case .pint: "pt"
        case .quart: "qt"
        case .gallon: "gal"
        case .count: ""
        }
    }

    public static func canonicalUnit(for family: UnitFamily) -> QuantityUnit {
        switch family {
        case .mass: .gram
        case .volume: .milliliter
        case .count: .count
        }
    }
}

public enum QuantityError: Error, Equatable, Sendable {
    case negativeAmount
    case nonFiniteAmount
    case fractionalCount
    case familyMismatch(QuantityUnit, QuantityUnit)
}

public struct Quantity: Equatable, Hashable, Sendable {
    public let canonicalAmount: Double
    public let unit: QuantityUnit

    public init(amount: Double, unit: QuantityUnit) throws {
        try Self.validate(amount, family: unit.family)
        canonicalAmount = amount * unit.canonicalFactor
        self.unit = unit
    }

    public init(canonicalAmount: Double, unit: QuantityUnit) throws {
        try Self.validate(canonicalAmount, family: unit.family)
        self.canonicalAmount = canonicalAmount
        self.unit = unit
    }

    public var family: UnitFamily { unit.family }

    public var amount: Double { canonicalAmount / unit.canonicalFactor }

    public func amount(in target: QuantityUnit) throws -> Double {
        guard target.family == unit.family else {
            throw QuantityError.familyMismatch(unit, target)
        }
        return canonicalAmount / target.canonicalFactor
    }

    private static func validate(_ amount: Double, family: UnitFamily) throws {
        guard amount.isFinite else {
            throw QuantityError.nonFiniteAmount
        }
        guard amount >= 0 else {
            throw QuantityError.negativeAmount
        }
        if family == .count, amount.truncatingRemainder(dividingBy: 1) != 0 {
            throw QuantityError.fractionalCount
        }
    }
}

extension Quantity: Codable {
    enum CodingKeys: String, CodingKey {
        case canonicalAmount
        case unit
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            canonicalAmount: container.decode(Double.self, forKey: .canonicalAmount),
            unit: container.decode(QuantityUnit.self, forKey: .unit)
        )
    }
}
