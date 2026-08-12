import Foundation

public struct PropagationID<Entity>: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static func generate() -> PropagationID<Entity> {
        PropagationID(rawValue: UUID().uuidString)
    }
}
