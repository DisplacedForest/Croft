import Foundation
import Testing

@testable import Domain

struct DayStampTests {
    @Test func validDaysConstructAndInvalidDaysDoNot() {
        #expect(DayStamp(year: 2026, month: 8, day: 18) != nil)
        #expect(DayStamp(year: 2026, month: 2, day: 29) != nil)
        #expect(DayStamp(year: 2026, month: 2, day: 30) == nil)
        #expect(DayStamp(year: 2026, month: 13, day: 1) == nil)
        #expect(DayStamp(year: 2026, month: 0, day: 1) == nil)
        #expect(DayStamp(year: 2026, month: 4, day: 31) == nil)
        #expect(DayStamp(year: 0, month: 1, day: 1) == nil)
    }

    @Test func storageFormRoundTrips() throws {
        let stamp = try #require(DayStamp(year: 2026, month: 8, day: 3))
        #expect(stamp.storageValue == "2026-08-03")
        #expect(DayStamp(storageValue: "2026-08-03") == stamp)
        for bad in ["2026-8-3", "18-08-2026", "2026/08/03", "", "2026-08-32"] {
            #expect(DayStamp(storageValue: bad) == nil)
        }
    }

    @Test func orderingFollowsTheCalendar() throws {
        let july = try #require(DayStamp(year: 2026, month: 7, day: 31))
        let august = try #require(DayStamp(year: 2026, month: 8, day: 1))
        let nextYear = try #require(DayStamp(year: 2027, month: 1, day: 1))
        #expect(july < august)
        #expect(august < nextYear)
        #expect(july.storageValue < august.storageValue)
        #expect(august.storageValue < nextYear.storageValue)
    }

    @Test func aDateMapsToItsCalendarDay() {
        let date = Date(timeIntervalSince1970: 1_720_000_000)
        let stamp = DayStamp(date)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        #expect(stamp.year == components.year)
        #expect(stamp.month == components.month)
        #expect(stamp.day == components.day)
    }
}
