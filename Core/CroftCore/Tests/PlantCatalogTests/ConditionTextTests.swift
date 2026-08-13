import PlantCatalog
import Testing

@Suite struct ConditionTextTests {
    @Test func daysRangeReadsAsSpan() {
        #expect(ConditionText.days(60...85) == "60 to 85 days")
    }

    @Test func daysSingleValueDropsTheSpan() {
        #expect(ConditionText.days(70...70) == "70 days")
    }

    @Test func centimetersDropWholeNumberDecimals() {
        #expect(ConditionText.centimeters(45.0...60.0) == "45 to 60 cm")
        #expect(ConditionText.centimeters(2.5...2.5) == "2.5 cm")
    }

    @Test func soilPHKeepsOneDecimal() {
        #expect(ConditionText.soilPH(6.0...6.8) == "pH 6.0 to 6.8")
        #expect(ConditionText.soilPH(7.0...7.0) == "pH 7.0")
    }
}
