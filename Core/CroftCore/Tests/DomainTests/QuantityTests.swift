import Foundation
import Testing

@testable import Domain

struct QuantityUnitTests {
    @Test func rawValuesAreStable() {
        #expect(
            QuantityUnit.allCases.map(\.rawValue) == [
                "gram", "kilogram", "ounce", "pound",
                "milliliter", "liter", "fluid_ounce", "cup", "pint", "quart", "gallon",
                "count",
            ])
    }

    @Test func everyUnitBelongsToOneFamily() {
        #expect(QuantityUnit.gram.family == .mass)
        #expect(QuantityUnit.kilogram.family == .mass)
        #expect(QuantityUnit.ounce.family == .mass)
        #expect(QuantityUnit.pound.family == .mass)
        #expect(QuantityUnit.milliliter.family == .volume)
        #expect(QuantityUnit.liter.family == .volume)
        #expect(QuantityUnit.fluidOunce.family == .volume)
        #expect(QuantityUnit.cup.family == .volume)
        #expect(QuantityUnit.pint.family == .volume)
        #expect(QuantityUnit.quart.family == .volume)
        #expect(QuantityUnit.gallon.family == .volume)
        #expect(QuantityUnit.count.family == .count)
    }

    @Test func imperialLadderIsInternallyExact() {
        #expect(QuantityUnit.pound.canonicalFactor == 16 * QuantityUnit.ounce.canonicalFactor)
        #expect(QuantityUnit.cup.canonicalFactor == 8 * QuantityUnit.fluidOunce.canonicalFactor)
        #expect(QuantityUnit.pint.canonicalFactor == 2 * QuantityUnit.cup.canonicalFactor)
        #expect(QuantityUnit.quart.canonicalFactor == 2 * QuantityUnit.pint.canonicalFactor)
        #expect(QuantityUnit.gallon.canonicalFactor == 4 * QuantityUnit.quart.canonicalFactor)
    }

    @Test func canonicalUnitPerFamily() {
        #expect(QuantityUnit.canonicalUnit(for: .mass) == .gram)
        #expect(QuantityUnit.canonicalUnit(for: .volume) == .milliliter)
        #expect(QuantityUnit.canonicalUnit(for: .count) == .count)
    }
}

struct QuantityTests {
    @Test func handCheckedCanonicalFixtures() throws {
        #expect(try Quantity(amount: 1, unit: .pound).canonicalAmount == 453.592_37)
        #expect(try Quantity(amount: 1, unit: .ounce).canonicalAmount == 28.349_523_125)
        #expect(try Quantity(amount: 1, unit: .kilogram).canonicalAmount == 1000)
        #expect(try Quantity(amount: 16, unit: .ounce).canonicalAmount == 453.592_37)
        #expect(try Quantity(amount: 1, unit: .fluidOunce).canonicalAmount == 29.573_529_562_5)
        #expect(try Quantity(amount: 1, unit: .gallon).canonicalAmount == 3785.411_784)
        #expect(try Quantity(amount: 4, unit: .quart).canonicalAmount == 3785.411_784)
        #expect(try Quantity(amount: 2, unit: .liter).canonicalAmount == 2000)
        #expect(try Quantity(amount: 7, unit: .count).canonicalAmount == 7)
    }

    @Test func conversionAcrossUnitsInOneFamily() throws {
        #expect(try Quantity(amount: 2, unit: .pound).amount(in: .ounce) == 32)
        #expect(try Quantity(amount: 1, unit: .liter).amount(in: .milliliter) == 1000)
        #expect(try Quantity(amount: 1, unit: .gallon).amount(in: .fluidOunce) == 128)
        let kilogramInPounds = try Quantity(amount: 1, unit: .kilogram).amount(in: .pound)
        #expect(abs(kilogramInPounds - 2.204_622_621_8) < 0.000_000_001)
    }

    @Test func crossFamilyConversionThrows() throws {
        let mass = try Quantity(amount: 1, unit: .gram)
        #expect(throws: QuantityError.familyMismatch(.gram, .liter)) {
            try mass.amount(in: .liter)
        }
    }

    @Test func negativeAmountsAreRejected() {
        #expect(throws: QuantityError.negativeAmount) {
            try Quantity(amount: -1, unit: .gram)
        }
        #expect(throws: QuantityError.negativeAmount) {
            try Quantity(canonicalAmount: -0.5, unit: .pound)
        }
    }

    @Test func nonFiniteAmountsAreRejected() {
        #expect(throws: QuantityError.nonFiniteAmount) {
            try Quantity(amount: .infinity, unit: .liter)
        }
        #expect(throws: QuantityError.nonFiniteAmount) {
            try Quantity(amount: .nan, unit: .count)
        }
    }

    @Test func countFamilyRejectsFractions() {
        #expect(throws: QuantityError.fractionalCount) {
            try Quantity(amount: 2.5, unit: .count)
        }
        #expect(throws: QuantityError.fractionalCount) {
            try Quantity(canonicalAmount: 0.1, unit: .count)
        }
    }

    @Test func zeroAndWholeCountsAreAccepted() throws {
        #expect(try Quantity(amount: 0, unit: .count).canonicalAmount == 0)
        #expect(try Quantity(amount: 12, unit: .count).amount == 12)
        #expect(try Quantity(amount: 0, unit: .gram).canonicalAmount == 0)
    }

    @Test func enteredAmountDerivesFromCanonical() throws {
        let quantity = try Quantity(canonicalAmount: 453.592_37, unit: .pound)
        #expect(quantity.amount == 1)
    }

    @Test func codableRoundTripIsIdentity() throws {
        let fixtures = try QuantityUnit.allCases.flatMap { unit in
            try [2, 1000].map { try Quantity(amount: Double($0), unit: unit) }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        for quantity in fixtures {
            let encoded = try encoder.encode(quantity)
            let decoded = try JSONDecoder().decode(Quantity.self, from: encoded)
            #expect(decoded == quantity)
            #expect(try encoder.encode(decoded) == encoded)
        }
    }

    @Test func decodingInvalidPayloadThrows() {
        let negative = Data(#"{"canonicalAmount":-3,"unit":"gram"}"#.utf8)
        #expect(throws: QuantityError.negativeAmount) {
            try JSONDecoder().decode(Quantity.self, from: negative)
        }
        let fractionalCount = Data(#"{"canonicalAmount":1.5,"unit":"count"}"#.utf8)
        #expect(throws: QuantityError.fractionalCount) {
            try JSONDecoder().decode(Quantity.self, from: fractionalCount)
        }
    }
}
