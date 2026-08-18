import Foundation
import Testing

@testable import Domain

private let unitedStates = Locale(identifier: "en_US")
private let germany = Locale(identifier: "de_DE")

struct QuantityFormatterTests {
    @Test func keepsEnteredUnitWhenItMatchesThePreferredSystem() throws {
        let formatter = QuantityFormatter(system: .metric, locale: unitedStates)
        #expect(try formatter.string(from: Quantity(amount: 1.5, unit: .kilogram)) == "1.5 kg")
        #expect(try formatter.string(from: Quantity(amount: 2500, unit: .gram)) == "2500 g")
        let imperial = QuantityFormatter(system: .imperial, locale: unitedStates)
        #expect(try imperial.string(from: Quantity(amount: 40, unit: .ounce)) == "40 oz")
        #expect(try imperial.string(from: Quantity(amount: 3, unit: .cup)) == "3 cup")
    }

    @Test func convertsMassIntoThePreferredSystemWithHumanScaling() throws {
        let imperial = QuantityFormatter(system: .imperial, locale: unitedStates)
        #expect(try imperial.string(from: Quantity(amount: 1.5, unit: .kilogram)) == "3.31 lb")
        #expect(try imperial.string(from: Quantity(amount: 100, unit: .gram)) == "3.53 oz")
        let metric = QuantityFormatter(system: .metric, locale: unitedStates)
        #expect(try metric.string(from: Quantity(amount: 8, unit: .ounce)) == "226.8 g")
        #expect(try metric.string(from: Quantity(amount: 5, unit: .pound)) == "2.27 kg")
    }

    @Test func convertsVolumeIntoThePreferredSystemWithHumanScaling() throws {
        let metric = QuantityFormatter(system: .metric, locale: unitedStates)
        #expect(try metric.string(from: Quantity(amount: 2, unit: .cup)) == "473.18 mL")
        #expect(try metric.string(from: Quantity(amount: 2, unit: .gallon)) == "7.57 L")
        let imperial = QuantityFormatter(system: .imperial, locale: unitedStates)
        #expect(
            try imperial.string(from: Quantity(amount: 500, unit: .milliliter)) == "16.91 fl oz")
        #expect(try imperial.string(from: Quantity(amount: 2, unit: .liter)) == "2.11 qt")
        #expect(try imperial.string(from: Quantity(amount: 5, unit: .liter)) == "1.32 gal")
    }

    @Test func canonicalTotalsScaleToTheReadableUnit() throws {
        let metric = QuantityFormatter(system: .metric, locale: unitedStates)
        #expect(metric.string(fromCanonical: 1350, family: .mass) == "1.35 kg")
        #expect(metric.string(fromCanonical: 940, family: .mass) == "940 g")
        let imperial = QuantityFormatter(system: .imperial, locale: unitedStates)
        #expect(imperial.string(fromCanonical: 1350, family: .mass) == "2.98 lb")
        #expect(imperial.string(fromCanonical: 6, family: .count) == "6")
    }

    @Test func countRendersBareInBothSystems() throws {
        let quantity = try Quantity(amount: 12, unit: .count)
        #expect(
            QuantityFormatter(system: .metric, locale: unitedStates).string(from: quantity) == "12")
        #expect(
            QuantityFormatter(system: .imperial, locale: unitedStates).string(from: quantity)
                == "12")
    }

    @Test func respectsTheLocaleDecimalSeparator() throws {
        let formatter = QuantityFormatter(system: .metric, locale: germany)
        #expect(try formatter.string(from: Quantity(amount: 1.5, unit: .kilogram)) == "1,5 kg")
    }
}

struct QuantityParserTests {
    @Test func acceptsDotAndCommaDecimals() throws {
        #expect(try Quantity.parse(amountText: "1.5", unit: .kilogram).amount == 1.5)
        #expect(try Quantity.parse(amountText: "1,5", unit: .kilogram).amount == 1.5)
        #expect(try Quantity.parse(amountText: " 2,25 ", unit: .pound).amount == 2.25)
    }

    @Test func acceptsZeroAndWholeNumbers() throws {
        #expect(try Quantity.parse(amountText: "0", unit: .gram).canonicalAmount == 0)
        #expect(try Quantity.parse(amountText: "7", unit: .count).amount == 7)
    }

    @Test func rejectsNegativeInput() {
        #expect(throws: QuantityParseError.negative) {
            try Quantity.parse(amountText: "-1", unit: .gram)
        }
        #expect(throws: QuantityParseError.negative) {
            try Quantity.parse(amountText: "-0,5", unit: .liter)
        }
    }

    @Test func rejectsMalformedInput() {
        for text in ["", "  ", "abc", "1.5.2", "1,5,2", "nan", "inf", "12kg"] {
            #expect(throws: QuantityParseError.malformed) {
                try Quantity.parse(amountText: text, unit: .gram)
            }
        }
    }

    @Test func rejectsFractionalCounts() {
        #expect(throws: QuantityParseError.fractionalCount) {
            try Quantity.parse(amountText: "2,5", unit: .count)
        }
    }
}

struct UnitSystemPreferenceTests {
    private func scratchDefaults() throws -> UserDefaults {
        let name = "quantity-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func defaultsToTheLocaleMeasurementSystem() throws {
        let store = try scratchDefaults()
        #expect(UnitSystemPreference(store: store, locale: unitedStates).system == .imperial)
        #expect(UnitSystemPreference(store: store, locale: germany).system == .metric)
    }

    @Test func storedChoiceWinsOverTheLocale() throws {
        let store = try scratchDefaults()
        let preference = UnitSystemPreference(store: store, locale: unitedStates)
        preference.system = .metric
        #expect(preference.system == .metric)
        #expect(UnitSystemPreference(store: store, locale: germany).system == .metric)
    }

    @Test func garbageStoredValueFallsBackToTheLocale() throws {
        let store = try scratchDefaults()
        store.set("cubits", forKey: "measurement.unitSystem")
        #expect(UnitSystemPreference(store: store, locale: unitedStates).system == .imperial)
    }
}
