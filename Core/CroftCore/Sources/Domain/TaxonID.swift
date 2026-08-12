import Foundation

public struct TaxonID<Entity>: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static func generate() -> TaxonID<Entity> {
        TaxonID(rawValue: UUID().uuidString)
    }
}
