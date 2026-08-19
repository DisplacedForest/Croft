import Domain
import Foundation
import Testing

private let calendar = PlantingWindows.utcCalendar

private func date(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = dayOfMonth
    return calendar.date(from: components)!
}

private func minimum(_ year: Int, _ month: Int, _ day: Int, _ celsius: Double) -> DailyMinimum {
    DailyMinimum(date: date(year, month, day), celsius: celsius)
}

struct FrostDerivationTests {
    @Test func temperateMediansComeOutByHand() throws {
        let minima = [
            minimum(2023, 4, 20, -2), minimum(2023, 5, 5, -1),
            minimum(2023, 7, 10, 12),
            minimum(2023, 10, 1, -1), minimum(2023, 11, 3, -4),
            minimum(2024, 5, 10, 0),
            minimum(2024, 10, 5, -2),
            minimum(2025, 4, 30, -3),
            minimum(2025, 9, 25, -1), minimum(2025, 10, 20, -5),
        ]
        let derived = ClimateDerivation.frostDates(
            minima: minima, southernHemisphere: false, calendar: calendar)
        #expect(derived.lastFrost == MonthDay(month: 5, day: 5))
        #expect(derived.firstFrost == MonthDay(month: 10, day: 1))
    }

    @Test func aNoFrostClimateYieldsNothing() throws {
        let minima = [
            minimum(2023, 1, 10, 8), minimum(2023, 7, 10, 18),
            minimum(2024, 1, 15, 6), minimum(2024, 8, 1, 20),
        ]
        let derived = ClimateDerivation.frostDates(
            minima: minima, southernHemisphere: false, calendar: calendar)
        #expect(derived.lastFrost == nil)
        #expect(derived.firstFrost == nil)
    }

    @Test func southernSeasonsWrapTheCalendarYear() throws {
        let minima = [
            minimum(2022, 7, 20, -2),
            minimum(2022, 9, 18, -1),
            minimum(2022, 12, 25, 15),
            minimum(2023, 5, 25, -1),
        ]
        let derived = ClimateDerivation.frostDates(
            minima: minima, southernHemisphere: true, calendar: calendar)
        #expect(derived.lastFrost == MonthDay(month: 9, day: 18))
        #expect(derived.firstFrost == MonthDay(month: 5, day: 25))
    }

    @Test func aFrostlessSeasonContributesNothingToTheMedian() throws {
        let minima = [
            minimum(2023, 5, 5, -1), minimum(2023, 10, 1, -1),
            minimum(2024, 1, 15, 6), minimum(2024, 7, 20, 14),
        ]
        let derived = ClimateDerivation.frostDates(
            minima: minima, southernHemisphere: false, calendar: calendar)
        #expect(derived.lastFrost == MonthDay(month: 5, day: 5))
        #expect(derived.firstFrost == MonthDay(month: 10, day: 1))
    }

    @Test func anEmptySeriesYieldsNothing() throws {
        let derived = ClimateDerivation.frostDates(
            minima: [], southernHemisphere: false, calendar: calendar)
        #expect(derived.lastFrost == nil)
        #expect(derived.firstFrost == nil)
    }

    @Test func aLeapYearMedianKeepsItsCalendarDay() throws {
        let minima = [minimum(2024, 10, 5, -2)]
        let derived = ClimateDerivation.frostDates(
            minima: minima, southernHemisphere: false, calendar: calendar)
        #expect(derived.firstFrost == MonthDay(month: 10, day: 5))
    }

    @Test func aLeapDayFrostClampsWithoutCrashing() throws {
        let minima = [minimum(2024, 2, 29, -5)]
        let derived = ClimateDerivation.frostDates(
            minima: minima, southernHemisphere: false, calendar: calendar)
        #expect(derived.lastFrost == MonthDay(month: 2, day: 28))
    }

    @Test func aSouthernNewYearsEveFrostStaysInTheSpringHalf() throws {
        let minima = [minimum(2022, 12, 31, -1)]
        let derived = ClimateDerivation.frostDates(
            minima: minima, southernHemisphere: true, calendar: calendar)
        #expect(derived.lastFrost == MonthDay(month: 12, day: 31))
        #expect(derived.firstFrost == nil)
    }
}

struct ZoneDerivationTests {
    @Test func coldTemperateLandsInZoneFive() throws {
        let minima = [
            minimum(2023, 1, 20, -25), minimum(2023, 7, 1, 15),
            minimum(2024, 1, 25, -28),
            minimum(2025, 2, 1, -22),
        ]
        let zone = ClimateDerivation.estimatedZone(
            minima: minima, southernHemisphere: false, calendar: calendar)
        #expect(zone == 5)
    }

    @Test func aWarmClimateLandsHigh() throws {
        let minima = [
            minimum(2023, 1, 10, 10),
            minimum(2024, 1, 15, 10),
        ]
        let zone = ClimateDerivation.estimatedZone(
            minima: minima, southernHemisphere: false, calendar: calendar)
        #expect(zone == 12)
    }

    @Test func extremeColdClampsToZoneOne() throws {
        let minima = [minimum(2023, 1, 10, -60)]
        let zone = ClimateDerivation.estimatedZone(
            minima: minima, southernHemisphere: false, calendar: calendar)
        #expect(zone == 1)
    }

    @Test func anEmptySeriesHasNoZone() throws {
        #expect(
            ClimateDerivation.estimatedZone(
                minima: [], southernHemisphere: false, calendar: calendar) == nil)
    }
}
