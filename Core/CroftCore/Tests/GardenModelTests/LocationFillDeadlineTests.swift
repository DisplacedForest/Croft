import Domain
import Foundation
import GardenModel
import Persistence
import Testing

private let coordinate = GeoCoordinate(latitude: 44.26, longitude: -72.58)!

private let series: [DailyMinimum] = [
    DailyMinimum(date: Date(timeIntervalSince1970: 1_683_244_800), celsius: -1),
    DailyMinimum(date: Date(timeIntervalSince1970: 1_696_118_400), celsius: -2),
    DailyMinimum(date: Date(timeIntervalSince1970: 1_674_172_800), celsius: -25),
]

private let never: @Sendable () async throws -> Void = {
    try await Task.sleep(for: .seconds(3600))
}

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0

    func next() -> Int {
        lock.withLock {
            calls += 1
            return calls
        }
    }
}

@MainActor
private func makeForm(
    reverseGeocode: ReverseGeocode? = nil,
    minima: HistoricalMinima? = nil
) throws -> PropertyDetailsForm {
    let database = try AppDatabase.inMemory()
    let defaults = UserDefaults(suiteName: "deadline-tests-\(UUID().uuidString)")!
    return PropertyDetailsForm(
        database: database,
        defaults: PropertySetupDefaults(store: defaults),
        fillCoordinate: { coordinate },
        reverseGeocode: reverseGeocode,
        minima: minima,
        climateCache: ClimateCache(store: defaults),
        geocodeDeadline: .milliseconds(50),
        minimaDeadline: .milliseconds(50)
    )
}

@Test @MainActor func aStalledReverseGeocodeFallsBackAndTheFlowCompletes() async throws {
    let form = try makeForm(
        reverseGeocode: { _ in
            try await never()
            return ResolvedPlace(name: "nowhere", coordinate: coordinate)
        },
        minima: { _ in series }
    )
    form.load()
    await form.useCurrentLocation()
    #expect(form.isFillingLocation == false)
    #expect(form.latitudeText == "44.26000")
    #expect(form.longitudeText == "-72.58000")
    #expect(
        form.addressMessage == "No address was found for this spot, so it stays as coordinates.")
    #expect(form.derivedClimate != nil)
}

@Test @MainActor func aStalledMinimaFetchEndsWithTheDerivationMessage() async throws {
    let form = try makeForm(
        minima: { _ in
            try await never()
            return []
        }
    )
    form.load()
    await form.useCurrentLocation()
    #expect(form.isFillingLocation == false)
    #expect(form.isDerivingClimate == false)
    #expect(
        form.derivationMessage
            == "Weather history is unavailable for this location, so zone and frost "
            + "dates were not derived. Enter them manually or try again later.")
}

@Test @MainActor func aTimedOutDerivationClearsItsMessageOnTheNextSuccess() async throws {
    let counter = CallCounter()
    let form = try makeForm(
        minima: { _ in
            if counter.next() == 1 {
                try await never()
            }
            return series
        }
    )
    form.load()
    await form.useCurrentLocation()
    #expect(form.derivationMessage != nil)
    await form.deriveClimate()
    #expect(form.derivationMessage == nil)
    #expect(form.derivedClimate != nil)
}
