import Domain
import Foundation
import Testing

struct MonthDayTests {
    @Test func validDatesConstruct() throws {
        #expect(MonthDay(month: 1, day: 1) != nil)
        #expect(MonthDay(month: 12, day: 31) != nil)
        #expect(MonthDay(month: 2, day: 29) != nil)
        #expect(MonthDay(month: 4, day: 30) != nil)
    }

    @Test func invalidDatesAreRejected() throws {
        #expect(MonthDay(month: 0, day: 1) == nil)
        #expect(MonthDay(month: 13, day: 1) == nil)
        #expect(MonthDay(month: 1, day: 0) == nil)
        #expect(MonthDay(month: 1, day: 32) == nil)
        #expect(MonthDay(month: 2, day: 30) == nil)
        #expect(MonthDay(month: 4, day: 31) == nil)
    }

    @Test func lastDayFollowsTheMonth() throws {
        #expect(MonthDay.lastDay(ofMonth: 2) == 29)
        #expect(MonthDay.lastDay(ofMonth: 9) == 30)
        #expect(MonthDay.lastDay(ofMonth: 12) == 31)
        #expect(MonthDay.lastDay(ofMonth: 0) == nil)
    }

    @Test func decodingRejectsInvalidPairs() throws {
        let data = Data(#"{"month": 2, "day": 30}"#.utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(MonthDay.self, from: data)
        }
    }

    @Test func codableRoundTrips() throws {
        let original = try #require(MonthDay(month: 5, day: 15))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MonthDay.self, from: data)
        #expect(decoded == original)
    }
}

struct GeoCoordinateTests {
    @Test func validCoordinatesConstruct() throws {
        #expect(GeoCoordinate(latitude: 0, longitude: 0) != nil)
        #expect(GeoCoordinate(latitude: -90, longitude: 180) != nil)
        #expect(GeoCoordinate(latitude: 90, longitude: -180) != nil)
    }

    @Test func outOfRangeCoordinatesAreRejected() throws {
        #expect(GeoCoordinate(latitude: 90.1, longitude: 0) == nil)
        #expect(GeoCoordinate(latitude: -90.1, longitude: 0) == nil)
        #expect(GeoCoordinate(latitude: 0, longitude: 180.1) == nil)
        #expect(GeoCoordinate(latitude: 0, longitude: -180.1) == nil)
    }

    @Test func decodingRejectsOutOfRangeValues() throws {
        let data = Data(#"{"latitude": 95, "longitude": 10}"#.utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(GeoCoordinate.self, from: data)
        }
    }
}

struct PropertyAnchorTests {
    @Test func aBarePropertyIsMissingEverything() throws {
        let property = Property(name: "Home")
        #expect(!property.hasFrostDates)
        #expect(property.missingAnchors == [.location, .hardinessZone, .frostDates])
    }

    @Test func aFullPropertyIsMissingNothing() throws {
        let property = Property(
            name: "Home",
            location: GeoCoordinate(latitude: 44.5, longitude: -72.8),
            hardinessZone: 4,
            lastFrost: MonthDay(month: 5, day: 15),
            firstFrost: MonthDay(month: 9, day: 28)
        )
        #expect(property.hasFrostDates)
        #expect(property.missingAnchors.isEmpty)
    }

    @Test func aSingleFrostDateStillCountsAsMissing() throws {
        let property = Property(
            name: "Home",
            lastFrost: MonthDay(month: 5, day: 15)
        )
        #expect(!property.hasFrostDates)
        #expect(property.missingAnchors.contains(.frostDates))
    }
}
