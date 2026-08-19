import Foundation
import Testing
import Today

private struct RecordingFallback: LocationProviding, @unchecked Sendable {
    let counter: Counter
    func currentLocation() async throws -> GeoLocation {
        counter.bump()
        return GeoLocation(latitude: 1, longitude: 2)
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var count: Int { lock.withLock { value } }
    func bump() { lock.withLock { value += 1 } }
}

struct StoredFirstLocationTests {
    @Test func aStoredCoordinateWinsWithoutTouchingTheFallback() async throws {
        let counter = Counter()
        let provider = StoredFirstLocationProvider(
            stored: { GeoLocation(latitude: 44.26, longitude: -72.58) },
            fallback: RecordingFallback(counter: counter)
        )
        let location = try await provider.currentLocation()
        #expect(location == GeoLocation(latitude: 44.26, longitude: -72.58))
        #expect(counter.count == 0)
    }

    @Test func noStoredCoordinateFallsBackToDeviceLocation() async throws {
        let counter = Counter()
        let provider = StoredFirstLocationProvider(
            stored: { nil },
            fallback: RecordingFallback(counter: counter)
        )
        let location = try await provider.currentLocation()
        #expect(location == GeoLocation(latitude: 1, longitude: 2))
        #expect(counter.count == 1)
    }
}
