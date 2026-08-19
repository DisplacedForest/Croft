import Foundation
import Persistence

enum DatabaseLocation {
    enum Choice: Equatable {
        case release
        case dev
        case custom(String)
    }

    static let devFileName = "croft-dev.sqlite"
    static let overrideVariable = "CROFT_DATABASE_PATH"

    static func choose(developerIDSigned: Bool, override: String?) -> Choice {
        if developerIDSigned {
            return .release
        }
        if let override, !override.isEmpty {
            return .custom(override)
        }
        return .dev
    }

    static func url(for choice: Choice) throws -> URL {
        switch choice {
        case .release:
            return try AppDatabase.defaultURL()
        case .dev:
            return try AppDatabase.defaultURL()
                .deletingLastPathComponent()
                .appendingPathComponent(devFileName, isDirectory: false)
        case .custom(let path):
            return URL(fileURLWithPath: path)
        }
    }

    static func url() throws -> URL {
        try url(for: current)
    }

    static let current: Choice = {
        #if os(macOS)
            return choose(
                developerIDSigned: BundleSignature.isDeveloperIDSigned(),
                override: ProcessInfo.processInfo.environment[overrideVariable]
            )
        #else
            return .release
        #endif
    }()
}
