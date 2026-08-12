import Foundation
import Testing

@testable import Domain

private func expectStableDiseaseRawValues<Value>(
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

struct DiseaseAttributeTests {
    @Test func pathogenTypeRawValuesAreStable() throws {
        try expectStableDiseaseRawValues(
            PathogenType.self,
            ["fungal", "bacterial", "viral", "oomycete", "nematode", "physiological"]
        )
    }
}

struct DiseaseModelTests {
    @Test func diseaseRoundTripsThroughJSON() throws {
        let disease = Disease(
            name: "Early Blight",
            pathogen: "Alternaria solani",
            pathogenType: .fungal,
            symptoms: "Dark concentric spots on lower leaves",
            affectedPlantParts: [.leaf, .stem, .fruit],
            transmission: "Wind and splashing water",
            prevention: ["Crop rotation", "Mulching"],
            management: ["Remove infected foliage", "Apply fungicide"]
        )
        let encoded = try JSONEncoder().encode(disease)
        #expect(try JSONDecoder().decode(Disease.self, from: encoded) == disease)
    }

    @Test func defaultsAreEmptyOrNil() {
        let disease = Disease(name: "Powdery Mildew", pathogenType: .fungal)
        #expect(disease.affectedPlantParts.isEmpty)
        #expect(disease.prevention.isEmpty)
        #expect(disease.management.isEmpty)
        #expect(disease.pathogen == nil)
        #expect(disease.symptoms == nil)
        #expect(disease.transmission == nil)
    }

    @Test func generatedIdentifiersAreUnique() {
        #expect(Disease.ID.generate() != Disease.ID.generate())
    }
}

struct PathogenModelTests {
    @Test func pathogenRoundTripsThroughJSON() throws {
        let pathogen = Pathogen(name: "Alternaria solani")
        let encoded = try JSONEncoder().encode(pathogen)
        #expect(try JSONDecoder().decode(Pathogen.self, from: encoded) == pathogen)
    }

    @Test func generatedIdentifiersAreUnique() {
        #expect(Pathogen.ID.generate() != Pathogen.ID.generate())
    }
}

struct EnvironmentalConditionModelTests {
    @Test func environmentalConditionRoundTripsThroughJSON() throws {
        let condition = EnvironmentalCondition(name: "warm humid conditions")
        let encoded = try JSONEncoder().encode(condition)
        #expect(try JSONDecoder().decode(EnvironmentalCondition.self, from: encoded) == condition)
    }

    @Test func generatedIdentifiersAreUnique() {
        #expect(EnvironmentalCondition.ID.generate() != EnvironmentalCondition.ID.generate())
    }
}
