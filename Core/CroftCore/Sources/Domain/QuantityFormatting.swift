import Foundation

public struct QuantityFormatter: Sendable {
    public let system: UnitSystem
    public let locale: Locale

    public init(system: UnitSystem, locale: Locale = .current) {
        self.system = system
        self.locale = locale
    }

    public func string(from quantity: Quantity) -> String {
        let unit = displayUnit(for: quantity)
        let amount = quantity.canonicalAmount / unit.canonicalFactor
        let number = numberString(for: amount)
        return unit.symbol.isEmpty ? number : "\(number) \(unit.symbol)"
    }

    public func string(fromCanonical canonicalAmount: Double, family: UnitFamily) -> String {
        let unit = Self.scaledUnit(forCanonical: canonicalAmount, family: family, in: system)
        let amount = canonicalAmount / unit.canonicalFactor
        let number = numberString(for: amount)
        return unit.symbol.isEmpty ? number : "\(number) \(unit.symbol)"
    }

    public func displayUnit(for quantity: Quantity) -> QuantityUnit {
        if quantity.unit.system == system || quantity.family == .count {
            return quantity.unit
        }
        return Self.scaledUnit(
            forCanonical: quantity.canonicalAmount, family: quantity.family, in: system)
    }

    static func scaledUnit(
        forCanonical canonicalAmount: Double,
        family: UnitFamily,
        in system: UnitSystem
    ) -> QuantityUnit {
        switch (family, system) {
        case (.mass, .metric):
            canonicalAmount < QuantityUnit.kilogram.canonicalFactor ? .gram : .kilogram
        case (.mass, .imperial):
            canonicalAmount < QuantityUnit.pound.canonicalFactor ? .ounce : .pound
        case (.volume, .metric):
            canonicalAmount < QuantityUnit.liter.canonicalFactor ? .milliliter : .liter
        case (.volume, .imperial):
            if canonicalAmount < QuantityUnit.quart.canonicalFactor {
                .fluidOunce
            } else if canonicalAmount < QuantityUnit.gallon.canonicalFactor {
                .quart
            } else {
                .gallon
            }
        case (.count, _):
            .count
        }
    }

    private func numberString(for amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? String(amount)
    }
}

public enum QuantityParseError: Error, Equatable, Sendable {
    case malformed
    case negative
    case fractionalCount
}

extension Quantity {
    public static func parse(amountText: String, unit: QuantityUnit) throws -> Quantity {
        let normalized =
            amountText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty, let value = Double(normalized), value.isFinite else {
            throw QuantityParseError.malformed
        }
        guard value >= 0 else {
            throw QuantityParseError.negative
        }
        if unit.family == .count, value.truncatingRemainder(dividingBy: 1) != 0 {
            throw QuantityParseError.fractionalCount
        }
        return try Quantity(amount: value, unit: unit)
    }
}
