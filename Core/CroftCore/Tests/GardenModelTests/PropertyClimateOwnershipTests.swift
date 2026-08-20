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
private func splitForm(slowNorthMilliseconds: Int) throws -> PropertyDetailsForm {
    let subtropical = [
        DailyMinimum(date: day(2023, 1, 10), celsius: 8),
        DailyMinimum(date: day(2024, 1, 12), celsius: 10),
    ]
    let database = try AppDatabase.inMemory()
    let defaults = UserDefaults(suiteName: "climate-consistency-\(UUID().uuidString)")!
    let minima: HistoricalMinima = { coordinate in
        if coordinate.latitude > 40 {
            try? await Task.sleep(for: .milliseconds(slowNorthMilliseconds))
            return temperateSeries
        }
        return subtropical
    }
    return PropertyDetailsForm(
        database: database,
        defaults: PropertySetupDefaults(store: defaults),
        minima: minima,
        climateCache: ClimateCache(store: defaults)
    )
}

@Test @MainActor func aCompetingLocationDuringSaveAbortsAndTheRetryPersistsIt() async throws {
    let form = try splitForm(slowNorthMilliseconds: 300)
    form.load()
    form.latitudeText = "44.26"
    form.longitudeText = "-72.58"

    let saving = Task { await form.save() }
    try await Task.sleep(for: .milliseconds(100))
    form.latitudeText = "27.90000"
    form.longitudeText = "-82.50000"
    await form.deriveClimate()
    #expect(form.zoneText == "11")

    #expect(await saving.value == false)
    #expect(form.property == nil)
    #expect(form.zoneText == "11")

    #expect(await form.save())
    #expect(form.property?.location == GeoCoordinate(latitude: 27.9, longitude: -82.5))
    #expect(form.property?.hardinessZone == HardinessZone(number: 11))
    #expect(form.property?.lastFrost == nil)
}

@Test @MainActor func aCancelledFlightNeverClearsANewerFlightForTheSameCoordinate() async throws {
    let form = try splitForm(slowNorthMilliseconds: 300)
    form.load()
    form.latitudeText = "44.26"
    form.longitudeText = "-72.58"
    let first = Task { await form.deriveClimate() }
    try await Task.sleep(for: .milliseconds(50))

    form.latitudeText = "27.90000"
    form.longitudeText = "-82.50000"
    await form.deriveClimate()
    #expect(form.zoneText == "11")

    form.latitudeText = "44.26"
    form.longitudeText = "-72.58"
    await form.deriveClimate()
    await first.value

    #expect(form.zoneText == "5")
    #expect(form.lastFrostMonth == 5)
    #expect(form.isDerivingClimate == false)
}

@Test @MainActor func aLocationOnlyRecordDerivesOnSave() async throws {
    let counter = MinimaCounter()
    let database = try AppDatabase.inMemory()
    let defaults = UserDefaults(suiteName: "climate-consistency-\(UUID().uuidString)")!
    let structures = GardenStructureRepository(database)
    let property = Property(name: "Home")
    try structures.create(property)
    try structures.updatePropertyDetails(
        property.id,
        PropertyDetails(
            location: GeoCoordinate(latitude: 44.26, longitude: -72.58),
            zoneSource: .derived,
            frostDatesSource: .derived
        )
    )
    let minima: HistoricalMinima = { _ in
        counter.bump()
        return temperateSeries
    }
    let form = PropertyDetailsForm(
        database: database,
        defaults: PropertySetupDefaults(store: defaults),
        minima: minima,
        climateCache: ClimateCache(store: defaults)
    )
    form.load()
    #expect(form.zoneText.isEmpty)

    #expect(await form.save())

    #expect(counter.count == 1)
    #expect(form.property?.hardinessZone == HardinessZone(number: 5))
    #expect(form.property?.lastFrost == MonthDay(month: 5, day: 5))
    #expect(form.property?.zoneSource == .derived)
}

@Test @MainActor func aPartialDerivedRecordSurvivesReloadWithWeatherUnavailable() async throws {
    struct MinimaFailure: Error {}
    let database = try AppDatabase.inMemory()
    let structures = GardenStructureRepository(database)
    let property = Property(name: "Home")
    try structures.create(property)
    try structures.updatePropertyDetails(
        property.id,
        PropertyDetails(
            location: GeoCoordinate(latitude: 27.9, longitude: -82.5),
            hardinessZone: HardinessZone(number: 11),
            zoneSource: .derived,
            frostDatesSource: .derived
        )
    )
    let defaults = UserDefaults(suiteName: "climate-ownership-\(UUID().uuidString)")!
    let minima: HistoricalMinima = { _ in
        throw MinimaFailure()
    }
    let form = PropertyDetailsForm(
        database: database,
        defaults: PropertySetupDefaults(store: defaults),
        minima: minima,
        climateCache: ClimateCache(store: defaults)
    )
    form.load()
    #expect(form.zoneText == "11")

    #expect(await form.save())

    #expect(form.property?.hardinessZone == HardinessZone(number: 11))
    #expect(form.property?.zoneSource == .derived)
    #expect(form.derivationMessage != nil)
    #expect(form.zoneText == "11")
}
