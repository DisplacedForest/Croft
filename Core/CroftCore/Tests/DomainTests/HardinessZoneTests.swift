import Domain
import Testing

struct HardinessZoneTests {
    @Test(arguments: [
        ("8", HardinessZone(number: 8)),
        ("8a", HardinessZone(number: 8, half: .colder)),
        ("8b", HardinessZone(number: 8, half: .warmer)),
        ("8B", HardinessZone(number: 8, half: .warmer)),
        (" 4a ", HardinessZone(number: 4, half: .colder)),
        ("1", HardinessZone(number: 1)),
        ("13b", HardinessZone(number: 13, half: .warmer)),
    ])
    func validTextParses(_ example: (String, HardinessZone?)) throws {
        let expected = try #require(example.1)
        #expect(HardinessZone(parsing: example.0) == expected)
    }

    @Test(arguments: ["", "0", "0b", "14", "14a", "8c", "b", "a8", "8ab", "-1a", "+8", "8 b"])
    func invalidTextIsRejected(_ text: String) {
        #expect(HardinessZone(parsing: text) == nil)
    }

    @Test(arguments: ["8", "8a", "8b", "13", "1a"])
    func descriptionRoundTrips(_ text: String) throws {
        let zone = try #require(HardinessZone(parsing: text))
        #expect(zone.description == text)
        #expect(HardinessZone(parsing: zone.description) == zone)
    }

    @Test func numberInitEnforcesTheRange() {
        #expect(HardinessZone(number: 0) == nil)
        #expect(HardinessZone(number: 14) == nil)
        #expect(HardinessZone(number: 13, half: .colder) != nil)
    }
}
