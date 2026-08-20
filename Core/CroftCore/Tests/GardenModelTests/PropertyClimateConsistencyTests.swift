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

@MainActor
private func makeForm(
    series: [DailyMinimum]? = temperateSeries,
    counter: MinimaCounter = MinimaCounter()
) throws -> PropertyDetailsForm {
    struct MinimaFailure: Error {}
    let database = try AppDatabase.inMemory()
    let defaults = UserDefaults(suiteName: "climate-consistency-\(UUID().uuidString)")!
    let minima: HistoricalMinima = { _ in
        counter.bump()
        guard let series else {
            throw MinimaFailure()
        }
        return series
    }
    return PropertyDetailsForm(
        database: database,
        defaults: PropertySetupDefaults(store: defaults),
        minima: minima,
        climateCache: ClimateCache(store: defaults)
    )
}

@Test @MainActor func aManualCoordinateEditNeverSavesStaleDerivedClimate() async throws {
    struct MinimaFailure: Error {}
    let database = try AppDatabase.inMemory()
    let defaults = UserDefaults(suiteName: "climate-consistency-\(UUID().uuidString)")!
    let minima: HistoricalMinima = { coordinate in
        guard coordinate.latitude > 40 else {
            throw MinimaFailure()
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
    await form.deriveClimate()
    #expect(form.zoneText == "5")

    form.latitudeText = "10.00000"
    form.longitudeText = "10.00000"
    #expect(await form.save())

    #expect(form.zoneText.isEmpty)
    #expect(form.lastFrostMonth == nil)
    #expect(form.property?.hardinessZone == nil)
    #expect(form.property?.lastFrost == nil)
    #expect(form.property?.zoneSource == .derived)
    #expect(form.derivationMessage != nil)
}

@Test @MainActor func aMatchingDerivationStillSavesItsValues() async throws {
    let form = try makeForm()
    form.load()
    form.latitudeText = "44.26"
    form.longitudeText = "-72.58"
    await form.deriveClimate()
    #expect(await form.save())
    #expect(form.property?.hardinessZone == HardinessZone(number: 5))
    #expect(form.property?.lastFrost == MonthDay(month: 5, day: 5))
    #expect(form.property?.firstFrost == MonthDay(month: 10, day: 1))
}

@Test @MainActor func aPartialRederivationClearsAbsentDerivedOutputs() async throws {
    let counter = MinimaCounter()
    let subtropical = [
        DailyMinimum(date: day(2023, 1, 10), celsius: 8),
        DailyMinimum(date: day(2024, 1, 12), celsius: 10),
    ]
    let database = try AppDatabase.inMemory()
    let defaults = UserDefaults(suiteName: "climate-tests-\(UUID().uuidString)")!
    let minima: HistoricalMinima = { coordinate in
        counter.bump()
        return coordinate.latitude > 40 ? temperateSeries : subtropical
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
    await form.deriveClimate()
    #expect(form.lastFrostMonth == 5)

    form.latitudeText = "27.90000"
    form.longitudeText = "-82.50000"
    await form.deriveClimate()

    #expect(form.zoneText == "11")
    #expect(form.lastFrostMonth == nil)
    #expect(form.lastFrostDay == nil)
    #expect(form.firstFrostMonth == nil)
}

@Test @MainActor func aFailedRederivationClearsDerivedValues() async throws {
    let counter = MinimaCounter()
    struct MinimaFailure: Error {}
    let database = try AppDatabase.inMemory()
    let defaults = UserDefaults(suiteName: "climate-tests-\(UUID().uuidString)")!
    let minima: HistoricalMinima = { coordinate in
        counter.bump()
        guard coordinate.latitude > 40 else {
            throw MinimaFailure()
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
    await form.deriveClimate()
    #expect(form.zoneText == "5")

    form.latitudeText = "10.00000"
    form.longitudeText = "10.00000"
    await form.deriveClimate()

    #expect(form.zoneText.isEmpty)
    #expect(form.lastFrostMonth == nil)
    #expect(form.derivationMessage != nil)

    await form.useDerivedZone()
    #expect(form.zoneText.isEmpty)
}

@Test @MainActor func anObsoleteDerivationResultIsDiscarded() async throws {
    let subtropical = [
        DailyMinimum(date: day(2023, 1, 10), celsius: 8),
        DailyMinimum(date: day(2024, 1, 12), celsius: 10),
    ]
    let database = try AppDatabase.inMemory()
    let defaults = UserDefaults(suiteName: "climate-tests-\(UUID().uuidString)")!
    let minima: HistoricalMinima = { coordinate in
        if coordinate.latitude > 40 {
            try? await Task.sleep(for: .milliseconds(400))
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
    let slow = Task { await form.deriveClimate() }
    try await Task.sleep(for: .milliseconds(50))

    form.latitudeText = "27.90000"
    form.longitudeText = "-82.50000"
    await form.deriveClimate()
    #expect(form.zoneText == "11")

    await slow.value
    #expect(form.zoneText == "11")
    #expect(form.lastFrostMonth == nil)
}

@Test @MainActor func anImmediateSaveDerivesForTheCoordinateBeingSaved() async throws {
    let form = try makeForm()
    form.load()
    form.latitudeText = "44.26"
    form.longitudeText = "-72.58"

    #expect(await form.save())

    #expect(form.property?.hardinessZone == HardinessZone(number: 5))
    #expect(form.property?.lastFrost == MonthDay(month: 5, day: 5))
    #expect(form.property?.zoneSource == .derived)
}

@Test @MainActor func anImmediateSaveWithoutWeatherPersistsHonestEmptiness() async throws {
    let form = try makeForm(series: nil)
    form.load()
    form.latitudeText = "44.26"
    form.longitudeText = "-72.58"

    #expect(await form.save())

    #expect(form.property?.hardinessZone == nil)
    #expect(form.property?.lastFrost == nil)
    #expect(form.derivationMessage != nil)
}

@Test @MainActor func highPrecisionCoordinatesSurviveReloadAndResave() async throws {
    let counter = MinimaCounter()
    let database = try AppDatabase.inMemory()
    let suiteName = "climate-consistency-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let minima: HistoricalMinima = { _ in
        counter.bump()
        return temperateSeries
    }
    let saving = PropertyDetailsForm(
        database: database,
        defaults: PropertySetupDefaults(store: defaults),
        minima: minima,
        climateCache: ClimateCache(store: defaults)
    )
    saving.load()
    saving.latitudeText = "44.123456789"
    saving.longitudeText = "-72.987654321"
    await saving.deriveClimate()
    #expect(saving.zoneText == "5")
    #expect(await saving.save())

    let reloaded = PropertyDetailsForm(
        database: database,
        defaults: PropertySetupDefaults(store: defaults),
        minima: minima,
        climateCache: ClimateCache(store: defaults)
    )
    reloaded.load()
    #expect(reloaded.zoneText == "5")
    #expect(await reloaded.save())

    #expect(reloaded.property?.hardinessZone == HardinessZone(number: 5))
    #expect(reloaded.property?.lastFrost != nil)
}

@MainActor
private func slowForm(delayMilliseconds: Int) throws -> PropertyDetailsForm {
    let database = try AppDatabase.inMemory()
    let defaults = UserDefaults(suiteName: "climate-consistency-\(UUID().uuidString)")!
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
