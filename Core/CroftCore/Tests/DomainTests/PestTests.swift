import Foundation
import Testing

@testable import Domain

private func expectStablePestRawValues<Value>(
    _ type: Value.Type,
    _ expected: [String]
) throws
where Value: RawRepresentable & CaseIterable & Codable & Equatable, Value.RawValue == String {
    let cases = Array(type.allCases)
    #expect(cases.map(\.rawValue) == expected)
    let encoded = try JSONEncoder().encode(cases)
    let json = "[\"" + expected.joined(separator: "\",\"") + "\"]"
    #expect(String(bytes: encoded, encoding: .utf8) == json)
    let decoded = try JSONDecoder().decode([Value].self, from: Data(json.utf8))
    #expect(decoded == cases)
}

struct PestAttributeTests {
    @Test func organismTypeRawValuesAreStable() throws {
        try expectStablePestRawValues(OrganismType.self, ["pest", "beneficial"])
    }

    @Test func seasonRawValuesAreStable() throws {
        try expectStablePestRawValues(Season.self, ["spring", "summer", "fall", "winter"])
    }

    @Test func plantPartRawValuesAreStable() throws {
        try expectStablePestRawValues(
            PlantPart.self,
            ["leaf", "stem", "root", "tuber", "bulb", "fruit", "seed", "flower"]
        )
    }

    @Test func plantPartIsSeparateFromHarvestablePart() {
        #expect(PlantPart.allCases.map(\.rawValue) == HarvestablePart.allCases.map(\.rawValue))
    }
}

struct PestModelTests {
    @Test func pestRoundTripsThroughJSON() throws {
        let pest = Pest(
            commonName: "Tomato Hornworm",
            scientificName: "Manduca quinquemaculata",
            organismType: .pest,
            description: "Large green caterpillar",
            lifeCycle: "One to two generations per year",
            affectedPlantParts: [.leaf, .stem, .fruit],
            typicalDamage: "Defoliation and scarred fruit",
            activeSeasons: [.summer, .fall],
            geographicRange: "North America"
        )
        let encoded = try JSONEncoder().encode(pest)
        #expect(try JSONDecoder().decode(Pest.self, from: encoded) == pest)
    }

    @Test func defaultsAreEmptyOrNil() {
        let pest = Pest(commonName: "Braconid Wasp", organismType: .beneficial)
        #expect(pest.affectedPlantParts.isEmpty)
        #expect(pest.activeSeasons.isEmpty)
        #expect(pest.scientificName == nil)
        #expect(pest.description == nil)
        #expect(pest.lifeCycle == nil)
        #expect(pest.typicalDamage == nil)
        #expect(pest.geographicRange == nil)
    }

    @Test func generatedIdentifiersAreUnique() {
        #expect(Pest.ID.generate() != Pest.ID.generate())
    }
}
