import Testing

@testable import Knowledge

struct UnitsTests {
    @Test func fahrenheitConvertsToRoundedCelsius() {
        #expect(Units.celsius(fromFahrenheit: 32) == 0)
        #expect(Units.celsius(fromFahrenheit: 95) == 35)
        #expect(Units.celsius(fromFahrenheit: 60) == 15.6)
    }

    @Test func inchesConvertToRoundedCentimeters() {
        #expect(Units.centimeters(fromInches: 1) == 2.5)
        #expect(Units.centimeters(fromInches: 0.25) == 0.6)
        #expect(Units.centimeters(fromInches: 36) == 91.4)
    }

    @Test func plainRangesParse() {
        #expect(Units.doubleRange("65-85") == 65...85)
        #expect(Units.doubleRange("1") == 1...1)
        #expect(Units.doubleRange("0.125-0.25") == 0.125...0.25)
        #expect(Units.intRange("5-10") == 5...10)
    }

    @Test func proseIsRejectedForPlainRanges() {
        #expect(Units.doubleRange("no harvest in year 1; crop in year 2") == nil)
        #expect(Units.doubleRange("set crowns level with the soil") == nil)
        #expect(Units.doubleRange(nil) == nil)
        #expect(Units.doubleRange("90-60") == nil)
    }

    @Test func measurementsParseFractionsAndUnits() {
        #expect(Units.centimeterRange(fromMeasurement: "1/2 inch") == 1.3...1.3)
        #expect(Units.centimeterRange(fromMeasurement: "1/16th inch") == 0.2...0.2)
        #expect(Units.centimeterRange(fromMeasurement: "12 to 18 inches") == 30.5...45.7)
        #expect(Units.centimeterRange(fromMeasurement: "1 to 2 feet") == 30.5...61)
        #expect(Units.centimeterRange(fromMeasurement: "3/4 - 1 inch") == 1.9...2.5)
        #expect(Units.centimeterRange(fromMeasurement: "Plant crown at soil level") == nil)
        #expect(Units.centimeterRange(fromMeasurement: "Surface") == nil)
    }

    @Test func fahrenheitRangesConvert() {
        #expect(Units.celsiusRange(fromFahrenheit: "65-85") == 18.3...29.4)
    }
}

struct SlugTests {
    @Test func slugsAreStable() {
        #expect(Slug.make("Solanum lycopersicum") == "solanum-lycopersicum")
        #expect(Slug.make("Brandywine (OP)") == "brandywine-op")
        #expect(Slug.make("  San Marzano II ") == "san-marzano-ii")
        #expect(Slug.make("Mâche") == "mâche")
    }

    @Test func knowledgeIDsAreNamespaced() {
        #expect(KnowledgeID.species("Solanum lycopersicum") == "species:solanum-lycopersicum")
        #expect(
            KnowledgeID.cultivar(speciesID: "species:solanum-lycopersicum", name: "Iron Lady")
                == "cultivar:solanum-lycopersicum/iron-lady")
        #expect(
            KnowledgeID.edge(from: "a", type: "HOST_OF", to: "b") == "edge:a|HOST_OF|b")
    }
}
