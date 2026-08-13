import Domain
import Foundation

public enum PhotoStoreError: Error, Hashable {
    case invalidIdentifier(String)
    case invalidRelativePath(String)
}

public struct PhotoStore: Sendable {
    private static let observationsDirectory = "observations"

    private let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public func add(_ data: Data, forObservation id: Observation.ID) throws -> String {
        let directory = try directory(forObservation: id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = UUID().uuidString
        try data.write(to: directory.appendingPathComponent(name, isDirectory: false))
        return "\(Self.observationsDirectory)/\(id.rawValue)/\(name)"
    }

    public func url(forRelativePath path: String) throws -> URL {
        try baseURL.appendingPathComponent(validated(relativePath: path), isDirectory: false)
    }

    public func removePhotos(forObservation id: Observation.ID) throws {
        let directory = try directory(forObservation: id)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return
        }
        try FileManager.default.removeItem(at: directory)
    }

    public func sweepFiles(
        forObservation id: Observation.ID,
        keeping paths: Set<String>,
        modifiedBefore cutoff: Date
    ) throws {
        let directory = try directory(forObservation: id)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return
        }
        let kept = Set(try paths.map { try url(forRelativePath: $0).standardizedFileURL.path })
        let entries = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
        for entry in entries where !kept.contains(entry.standardizedFileURL.path) {
            let values = try entry.resourceValues(forKeys: [.contentModificationDateKey])
            guard let modified = values.contentModificationDate, modified < cutoff else {
                continue
            }
            try FileManager.default.removeItem(at: entry)
        }
    }

    public func orphanedIdentifiers(keeping ids: Set<String>) throws -> [String] {
        guard FileManager.default.fileExists(atPath: observationsRoot.path) else {
            return []
        }
        let entries = try FileManager.default.contentsOfDirectory(
            at: observationsRoot, includingPropertiesForKeys: nil)
        return entries.map(\.lastPathComponent).filter { !ids.contains($0) }
    }

    private var observationsRoot: URL {
        baseURL.appendingPathComponent(Self.observationsDirectory, isDirectory: true)
    }

    private func directory(forObservation id: Observation.ID) throws -> URL {
        observationsRoot.appendingPathComponent(try validated(id), isDirectory: true)
    }

    private func validated(_ id: Observation.ID) throws -> String {
        let raw = id.rawValue
        guard !raw.isEmpty, raw != ".", raw != "..", !raw.contains("/"), !raw.contains("\\") else {
            throw PhotoStoreError.invalidIdentifier(raw)
        }
        return raw
    }

    private func validated(relativePath path: String) throws -> String {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\"),
            !components.contains(".."), !components.contains("")
        else {
            throw PhotoStoreError.invalidRelativePath(path)
        }
        return path
    }
}
