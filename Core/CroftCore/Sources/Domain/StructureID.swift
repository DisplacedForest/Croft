import Foundation

public struct StructureID<Entity>: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static func generate() -> StructureID<Entity> {
        StructureID(rawValue: UUID().uuidString)
    }
}
