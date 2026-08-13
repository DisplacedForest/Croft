import Domain
import Foundation

public struct PhotoStore: Sendable {
    private static let observationsDirectory = "observations"

    private let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public func add(_ data: Data, forObservation id: Observation.ID) throws -> String {
        let directory = directory(forObservation: id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = UUID().uuidString
        try data.write(to: directory.appendingPathComponent(name, isDirectory: false))
        return "\(Self.observationsDirectory)/\(id.rawValue)/\(name)"
    }

    public func url(forRelativePath path: String) -> URL {
        baseURL.appendingPathComponent(path, isDirectory: false)
    }

    public func removePhotos(forObservation id: Observation.ID) throws {
        let directory = directory(forObservation: id)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return
        }
        try FileManager.default.removeItem(at: directory)
    }

    public func sweepOrphans(keeping ids: Set<String>) throws {
        let root = baseURL.appendingPathComponent(
            Self.observationsDirectory, isDirectory: true)
        guard FileManager.default.fileExists(atPath: root.path) else {
            return
        }
        let entries = try FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil)
        for entry in entries where !ids.contains(entry.lastPathComponent) {
            try FileManager.default.removeItem(at: entry)
        }
    }

    private func directory(forObservation id: Observation.ID) -> URL {
        baseURL
            .appendingPathComponent(Self.observationsDirectory, isDirectory: true)
            .appendingPathComponent(id.rawValue, isDirectory: true)
    }
}
