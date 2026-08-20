import Domain
import Foundation
import GardenModel
import Persistence
import Testing

private let calendar = PlantingWindows.utcCalendar

private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = dayOfMonth
    return calendar.date(from: components)!
}

private let temperateSeries: [DailyMinimum] = [
    DailyMinimum(date: day(2023, 5, 5), celsius: -1),
    DailyMinimum(date: day(2023, 10, 1), celsius: -1),
    DailyMinimum(date: day(2023, 1, 20), celsius: -25),
    DailyMinimum(date: day(2024, 5, 5), celsius: -2),
    DailyMinimum(date: day(2024, 10, 1), celsius: -3),
    DailyMinimum(date: day(2024, 1, 25), celsius: -25),
]

private final class MinimaCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var served = 0
    var count: Int { lock.withLock { served } }
    func bump() { lock.withLock { served += 1 } }
}

private final class MinimaGate: @unchecked Sendable {
    private let lock = NSLock()
    private var held = false
    private var released = false
    private var continuation: CheckedContinuation<Void, Never>?

    func holdFirstCaller() async {
        let shouldHold: Bool = lock.withLock {
            if held || released {
                return false
            }
            held = true
            return true
        }
        guard shouldHold else {
            return
        }
        await withCheckedContinuation { continuation in
            let resumeNow: Bool = lock.withLock {
                if released {
                    return true
                }
                self.continuation = continuation
                return false
            }
            if resumeNow {
                continuation.resume()
            }
        }
    }

    func release() {
        let continuation: CheckedContinuation<Void, Never>? = lock.withLock {
            released = true
            let held = self.continuation
            self.continuation = nil
            return held
        }
        continuation?.resume()
    }
}

@MainActor
private func slowForm(delayMilliseconds: Int) throws -> PropertyDetailsForm {
    let database = try AppDatabase.inMemory()
    let defaults = UserDefaults(suiteName: "climate-ownership-\(UUID().uuidString)")!
    let minima: HistoricalMinima = { _ in
        try? await Task.sleep(for: .milliseconds(delayMilliseconds))
        return temperateSeries
    }
    return PropertyDetailsForm(
        database: database,
        defaults: PropertySetupDefaults(store: defaults),
        minima: minima,
        climateCache: ClimateCache(store: defaults)
    )
}

@Test @MainActor func aDebouncedDerivationDuringSaveDoesNothingAndCostsNoRequest() async throws {
    let counter = MinimaCounter()
    let database = try AppDatabase.inMemory()
    let defaults = UserDefaults(suiteName: "climate-consistency-\(UUID().uuidString)")!
    let minima: HistoricalMinima = { _ in
        counter.bump()
        try? await Task.sleep(for: .milliseconds(300))
        return temperateSeries
    }
    let form = PropertyDetailsForm(
        database: database,
        defaults: PropertySetupDefaults(store: defaults),
        minima: minima,
        climateCache: ClimateCache(store: defaults)
    )
    form.load()
    form.latitudeText = "44.26"
    form.longitudeText = "-72.58"

    let saving = Task { await form.save() }
    try await Task.sleep(for: .milliseconds(100))
    await form.deriveClimate()
    #expect(form.isDerivingClimate == false)

    #expect(await saving.value)
    #expect(counter.count == 1)
    #expect(form.property?.hardinessZone == HardinessZone(number: 5))
    #expect(form.property?.lastFrost == MonthDay(month: 5, day: 5))
    #expect(form.property?.location == GeoCoordinate(latitude: 44.26, longitude: -72.58))
    #expect(form.zoneText == "5")
}

@Test @MainActor func anEditDuringSaveAbortsInsteadOfPersistingStaleState() async throws {
    let form = try slowForm(delayMilliseconds: 300)
    form.load()
    form.latitudeText = "44.26"
    form.longitudeText = "-72.58"

    let saving = Task { await form.save() }
    try await Task.sleep(for: .milliseconds(100))
    form.latitudeText = "10.00000"
    form.longitudeText = "10.00000"

    #expect(await saving.value == false)
    #expect(form.property == nil)
    #expect(form.latitudeText == "10.00000")
}

@Test @MainActor func aSourceFlipDuringSaveAbortsAndTheRetryPersistsTheCustomValue() async throws {
    let form = try slowForm(delayMilliseconds: 300)
    form.load()
    form.latitudeText = "44.26"
    form.longitudeText = "-72.58"

    let saving = Task { await form.save() }
    try await Task.sleep(for: .milliseconds(100))
    form.adjustZone()
    form.zoneText = "8b"

    #expect(await saving.value == false)
    #expect(form.property == nil)
    #expect(form.zoneText == "8b")

    #expect(await form.save())
    #expect(form.property?.hardinessZone == HardinessZone(parsing: "8b"))
    #expect(form.property?.zoneSource == .user)
    #expect(form.property?.lastFrost == MonthDay(month: 5, day: 5))
    #expect(form.property?.frostDatesSource == .derived)
}

@Test @MainActor func saveIsSingleFlight() async throws {
    let form = try slowForm(delayMilliseconds: 300)
    form.load()
    form.latitudeText = "44.26"
    form.longitudeText = "-72.58"

    let first = Task { await form.save() }
    try await Task.sleep(for: .milliseconds(50))
    #expect(form.isSaving)
    let second = await form.save()

    #expect(second == false)
    #expect(await first.value)
    #expect(form.isSaving == false)
    #expect(form.property?.hardinessZone == HardinessZone(number: 5))
}

@Test @MainActor func saveRetiresASlowFlightWithoutStrandingTheIndicator() async throws {
    let form = try slowForm(delayMilliseconds: 400)
    form.load()
    form.latitudeText = "44.26"
    form.longitudeText = "-72.58"

    let flight = Task { await form.deriveClimate() }
    try await Task.sleep(for: .milliseconds(50))

    #expect(await form.save())
    await flight.value

    #expect(form.isDerivingClimate == false)
    #expect(form.property?.hardinessZone == HardinessZone(number: 5))
    #expect(form.property?.lastFrost == MonthDay(month: 5, day: 5))
}

@Test @MainActor func aRetiredSuspendedFlightWritesNothingAndTheIndicatorEndsFalse() async throws {
    let gate = MinimaGate()
    let counter = MinimaCounter()
    let database = try AppDatabase.inMemory()
    let defaults = UserDefaults(suiteName: "climate-consistency-\(UUID().uuidString)")!
    let minima: HistoricalMinima = { _ in
        counter.bump()
        await gate.holdFirstCaller()
        return temperateSeries
    }
    let form = PropertyDetailsForm(
        database: database,
        defaults: PropertySetupDefaults(store: defaults),
        minima: minima,
        climateCache: ClimateCache(store: defaults)
    )
    form.load()
    form.latitudeText = "44.26"
    form.longitudeText = "-72.58"

    let flight = Task { await form.deriveClimate() }
    while counter.count < 1 {
        await Task.yield()
    }

    let saving = Task { await form.save() }
    try await Task.sleep(for: .milliseconds(50))
    gate.release()

    #expect(await saving.value)
    await flight.value

    #expect(form.isDerivingClimate == false)
    #expect(form.property?.hardinessZone == HardinessZone(number: 5))
    #expect(form.zoneText == "5")
    #expect(counter.count == 2)
}

@Test @MainActor func aRetiredFlightNeverPoisonsTheSharedCache() async throws {
    let gate = MinimaGate()
    let counter = MinimaCounter()
    let subtropical = [
        DailyMinimum(date: day(2023, 1, 10), celsius: 8),
        DailyMinimum(date: day(2024, 1, 12), celsius: 10),
    ]
    let database = try AppDatabase.inMemory()
    let suiteName = "climate-lifecycle-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let minima: HistoricalMinima = { _ in
        counter.bump()
        if counter.count == 1 {
            await gate.holdFirstCaller()
            return subtropical
        }
        return temperateSeries
    }
    let form = PropertyDetailsForm(
        database: database,
        defaults: PropertySetupDefaults(store: defaults),
        minima: minima,
        climateCache: ClimateCache(store: defaults)
    )
    form.load()
    form.latitudeText = "44.26"
    form.longitudeText = "-72.58"

    let flight = Task { await form.deriveClimate() }
    while counter.count < 1 {
        await Task.yield()
    }
    #expect(await form.save())
    #expect(form.property?.hardinessZone == HardinessZone(number: 5))

    gate.release()
    await flight.value

    let fresh = PropertyDetailsForm(
        database: database,
        defaults: PropertySetupDefaults(store: defaults),
        minima: minima,
        climateCache: ClimateCache(store: defaults)
    )
    fresh.load()
    await fresh.useDerivedZone()
    #expect(fresh.zoneText == "5")
}

@Test @MainActor func aDerivationDroppedDuringSaveReplaysAfterward() async throws {
    let gate = MinimaGate()
    let counter = MinimaCounter()
    let subtropical = [
        DailyMinimum(date: day(2023, 1, 10), celsius: 8),
        DailyMinimum(date: day(2024, 1, 12), celsius: 10),
    ]
    let database = try AppDatabase.inMemory()
    let defaults = UserDefaults(suiteName: "climate-lifecycle-\(UUID().uuidString)")!
    let minima: HistoricalMinima = { coordinate in
        counter.bump()
        if coordinate.latitude > 40 {
            await gate.holdFirstCaller()
            return temperateSeries
        }
        return subtropical
    }
    let form = PropertyDetailsForm(
        database: database,
        defaults: PropertySetupDefaults(store: defaults),
        minima: minima,
        climateCache: ClimateCache(store: defaults)
    )
    form.load()
    form.latitudeText = "44.26"
    form.longitudeText = "-72.58"

    let saving = Task { await form.save() }
    try await Task.sleep(for: .milliseconds(50))
    form.latitudeText = "27.90000"
    form.longitudeText = "-82.50000"
    await form.deriveClimate()
    #expect(form.isDerivingClimate == false)
    gate.release()

    #expect(await saving.value == false)
    #expect(form.property == nil)
    #expect(form.zoneText == "11")
    #expect(form.lastFrostMonth == nil)
}
