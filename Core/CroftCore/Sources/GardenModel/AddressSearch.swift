import Foundation

import struct Domain.DailyMinimum
import struct Domain.GeoCoordinate
import struct Domain.MonthDay

public struct AddressSuggestion: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String

    public init(id: String, title: String, subtitle: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

public struct ResolvedPlace: Equatable, Sendable {
    public let name: String
    public let coordinate: GeoCoordinate

    public init(name: String, coordinate: GeoCoordinate) {
        self.name = name
        self.coordinate = coordinate
    }
}

public protocol AddressSearching: Sendable {
    func suggestions(for query: String) async -> [AddressSuggestion]
    func resolve(_ suggestion: AddressSuggestion) async throws -> ResolvedPlace
}

public typealias HistoricalMinima = @Sendable (GeoCoordinate) async throws -> [DailyMinimum]

public struct DerivedClimate: Codable, Equatable, Sendable {
    public let zone: Int?
    public let lastFrost: MonthDay?
    public let firstFrost: MonthDay?

    public init(zone: Int?, lastFrost: MonthDay?, firstFrost: MonthDay?) {
        self.zone = zone
        self.lastFrost = lastFrost
        self.firstFrost = firstFrost
    }

    public var isEmpty: Bool {
        zone == nil && lastFrost == nil && firstFrost == nil
    }
}

public enum PropertyClimateField: CaseIterable, Hashable, Sendable {
    case zone
    case lastFrost
    case firstFrost
}

public struct ClimateCache {
    private let store: UserDefaults
    private static let keyPrefix = "climate.derived."

    public init(store: UserDefaults = .standard) {
        self.store = store
    }

    public func cached(for coordinate: GeoCoordinate) -> DerivedClimate? {
        guard let data = store.data(forKey: ClimateCache.key(for: coordinate)) else {
            return nil
        }
        return try? JSONDecoder().decode(DerivedClimate.self, from: data)
    }

    public func remember(_ climate: DerivedClimate, for coordinate: GeoCoordinate) {
        guard let data = try? JSONEncoder().encode(climate) else {
            return
        }
        store.set(data, forKey: ClimateCache.key(for: coordinate))
    }

    static func key(for coordinate: GeoCoordinate) -> String {
        let lat = (coordinate.latitude * 100).rounded() / 100
        let lon = (coordinate.longitude * 100).rounded() / 100
        return "\(keyPrefix)\(lat),\(lon)"
    }
}
