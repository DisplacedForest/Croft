import Foundation

public struct HardinessZone: Equatable, Hashable, Sendable {
    public enum Half: String, Equatable, Hashable, Sendable {
        case colder = "a"
        case warmer = "b"
    }

    public let number: Int
    public let half: Half?

    public init?(number: Int, half: Half? = nil) {
        guard (1...13).contains(number) else {
            return nil
        }
        self.number = number
        self.half = half
    }

    public init?(parsing text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        var digits = trimmed
        var half: Half?
        if let last = trimmed.last, let parsed = Half(rawValue: String(last)) {
            half = parsed
            digits = String(trimmed.dropLast())
        }
        guard
            !digits.isEmpty,
            digits.allSatisfy({ ("0"..."9").contains($0) }),
            let number = Int(digits)
        else {
            return nil
        }
        self.init(number: number, half: half)
    }
}

extension HardinessZone: CustomStringConvertible {
    public var description: String {
        half.map { "\(number)\($0.rawValue)" } ?? String(number)
    }
}

extension HardinessZone: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let zone = HardinessZone(parsing: text) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "invalid hardiness zone '\(text)'"
            )
        }
        self = zone
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
