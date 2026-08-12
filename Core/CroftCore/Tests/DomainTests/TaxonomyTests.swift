import Foundation
import Testing

@testable import Domain

private func expectStableRawValues<Value>(
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

struct TaxonomyAttributeTests {
    @Test func lifeCycleRawValuesAreStable() throws {
        try expectStableRawValues(LifeCycle.self, ["annual", "biennial", "perennial"])
    }

    @Test func growthHabitRawValuesAreStable() throws {
        try expectStableRawValues(
            GrowthHabit.self,
            ["upright", "bush", "vine", "sprawling", "rosette", "clumping"]
        )
    }

    @Test func sunExposureRawValuesAreStable() throws {
        try expectStableRawValues(
            SunExposure.self,
            ["fullSun", "partialSun", "partialShade", "fullShade"]
        )
    }

    @Test func waterNeedRawValuesAreStable() throws {
        try expectStableRawValues(WaterNeed.self, ["low", "moderate", "high"])
    }

    @Test func harvestablePartRawValuesAreStable() throws {
        try expectStableRawValues(
            HarvestablePart.self,
            ["leaf", "stem", "root", "tuber", "bulb", "fruit", "seed", "flower"]
        )
    }
}

struct TaxonIDTests {
    @Test func generatedIdentifiersAreUnique() {
        #expect(PlantFamily.ID.generate() != PlantFamily.ID.generate())
    }

    @Test func identifierEncodesAsItsRawString() throws {
        let identifier = Genus.ID(rawValue: "genus-1")
        let encoded = try JSONEncoder().encode([identifier])
        #expect(String(bytes: encoded, encoding: .utf8) == "[\"genus-1\"]")
        let decoded = try JSONDecoder().decode([Genus.ID].self, from: encoded)
        #expect(decoded == [identifier])
    }
}

struct TaxonomyModelCodableTests {
    private func roundTrip<Value: Codable & Equatable>(_ value: Value) throws -> Value {
        let encoded = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(Value.self, from: encoded)
    }

    @Test func plantFamilyRoundTripsThroughJSON() throws {
        let family = PlantFamily(name: "Solanaceae", commonNames: ["nightshade"])
        #expect(try roundTrip(family) == family)
    }

    @Test func genusRoundTripsThroughJSON() throws {
        let genus = Genus(familyID: .generate(), name: "Solanum")
        #expect(try roundTrip(genus) == genus)
    }

    @Test func speciesRoundTripsThroughJSON() throws {
        let species = Species(
            genusID: .generate(),
            scientificName: "Solanum lycopersicum",
            commonNames: ["tomato", "love apple"],
            lifeCycle: .annual,
            growthHabit: .vine,
            sunExposure: .fullSun,
            waterNeed: .moderate,
            soilPH: 6.0...6.8,
            spacingCentimeters: 45.0...60.0,
            daysToMaturity: 60...85,
            hardinessZones: 2...11,
            harvestableParts: [.fruit, .seed]
        )
        #expect(try roundTrip(species) == species)
    }

    @Test func cultivarRoundTripsThroughJSON() throws {
        let cultivar = Cultivar(
            speciesID: .generate(),
            name: "Brandywine",
            commonNames: ["brandywine tomato"],
            daysToMaturity: 80...100,
            spacingCentimeters: 60.0...90.0,
            growthHabit: .vine
        )
        #expect(try roundTrip(cultivar) == cultivar)
    }

    @Test func defaultsAreEmptyOrNil() {
        let species = Species(genusID: .generate(), scientificName: "Daucus carota")
        #expect(species.commonNames.isEmpty)
        #expect(species.harvestableParts.isEmpty)
        #expect(species.lifeCycle == nil)
        #expect(species.soilPH == nil)
        #expect(species.daysToMaturity == nil)
    }
}
