import CryptoKit
import Foundation

public struct InputsLock: Codable, Equatable, Sendable {
    public var pinned: [String: String]
    public var upstream: [String: String]

    public init(pinned: [String: String], upstream: [String: String] = [:]) {
        self.pinned = pinned
        self.upstream = upstream
    }

    public static let fileName = "inputs.lock.json"

    public static func load(from directory: URL) throws -> InputsLock {
        let url = directory.appendingPathComponent(fileName)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportError.missingInput(url.lastPathComponent)
        }
        return try JSONDecoder().decode(InputsLock.self, from: data)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    public static func checksum(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public func verify(fileName: String, data: Data) throws {
        guard let expected = pinned[fileName] else {
            throw ImportError.unpinnedInput(fileName)
        }
        let actual = Self.checksum(of: data)
        guard expected == actual else {
            throw ImportError.checksumMismatch(
                file: fileName, expected: expected, actual: actual)
        }
    }
}
