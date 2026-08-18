import Foundation

import struct Domain.DailyMinimum

public protocol HistoricalMinimaProviding: Sendable {
    func dailyMinima(at location: GeoLocation, from start: Date, to end: Date) async throws
        -> [DailyMinimum]
}

public struct StoredFirstLocationProvider: LocationProviding {
    private let stored: @Sendable () -> GeoLocation?
    private let fallback: any LocationProviding

    public init(
        stored: @escaping @Sendable () -> GeoLocation?,
        fallback: any LocationProviding
    ) {
        self.stored = stored
        self.fallback = fallback
    }

    public func currentLocation() async throws -> GeoLocation {
        if let location = stored() {
            return location
        }
        return try await fallback.currentLocation()
    }
}
