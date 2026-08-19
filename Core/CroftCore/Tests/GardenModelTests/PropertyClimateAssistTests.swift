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

private let vermont = GeoCoordinate(latitude: 44.26, longitude: -72.58)!

private let temperateSeries: [DailyMinimum] = [
    DailyMinimum(date: day(2023, 5, 5), celsius: -1),
    DailyMinimum(date: day(2023, 10, 1), celsius: -1),
    DailyMinimum(date: day(2023, 1, 20), celsius: -25),
    DailyMinimum(date: day(2024, 5, 5), celsius: -2),
    DailyMinimum(date: day(2024, 10, 1), celsius: -3),
    DailyMinimum(date: day(2024, 1, 25), celsius: -25),
]

private struct StubAddressSearch: AddressSearching {
    var results: [AddressSuggestion] = [
        AddressSuggestion(id: "s1", title: "Montpelier", subtitle: "Vermont, United States")
    ]
    var resolved: ResolvedPlace? = ResolvedPlace(name: "Montpelier, Vermont", coordinate: vermont)

    struct NoMatch: Error {}

    func suggestions(for query: String) async -> [AddressSuggestion] {
        results
    }

    func resolve(_ suggestion: AddressSuggestion) async throws -> ResolvedPlace {
        guard let resolved else {
            throw NoMatch()
        }
        return resolved
    }
}

private final class MinimaCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var served = 0
    var count: Int { lock.withLock { served } }
    func bump() { lock.withLock { served += 1 } }
}

@MainActor
private func makeForm(
    search: StubAddressSearch? = StubAddressSearch(),
    series: [DailyMinimum]? = temperateSeries,
    counter: MinimaCounter = MinimaCounter(),
    suite: String = UUID().uuidString,
    fillCoordinate: CoordinateFill? = nil,
    reverseGeocode: ReverseGeocode? = nil
) throws -> PropertyDetailsForm {
    struct MinimaFailure: Error {}
    let database = try AppDatabase.inMemory()
    let defaults = UserDefaults(suiteName: "climate-tests-\(suite)")!
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
        fillCoordinate: fillCoordinate,
        addressSearch: search,
        reverseGeocode: reverseGeocode,
        minima: minima,
        climateCache: ClimateCache(store: defaults)
    )
}

@Test @MainActor func typingSearchesAndShortQueriesClear() async throws {
    let form = try makeForm()
    form.load()
    form.addressQuery = "Mont"
    await form.searchAddresses()
    #expect(form.addressSuggestions.count == 1)
    form.addressQuery = "Mo"
    await form.searchAddresses()
    #expect(form.addressSuggestions.isEmpty)
}

@Test @MainActor func selectingASuggestionFillsCoordinatesAndDerivesPrefills() async throws {
    let form = try makeForm()
    form.load()
    form.addressQuery = "Montpelier"
    await form.searchAddresses()
    await form.selectSuggestion(form.addressSuggestions[0])

    #expect(form.latitudeText == "44.26000")
    #expect(form.longitudeText == "-72.58000")
    #expect(form.addressQuery == "Montpelier, Vermont")
    #expect(form.derivedPrefilled == [.zone, .lastFrost, .firstFrost])
    #expect(form.zoneText == "5")
    #expect(form.lastFrostMonth == 5)
    #expect(form.lastFrostDay == 5)
    #expect(form.firstFrostMonth == 10)
    #expect(form.firstFrostDay == 1)
    #expect(form.climateSuggestions.isEmpty)
    #expect(form.save())
}

@Test @MainActor func occupiedFieldsGetSuggestionsNotOverwrites() async throws {
    let form = try makeForm()
    form.load()
    form.zoneText = "7"
    form.lastFrostMonth = 4
    form.lastFrostDay = 15
    form.latitudeText = "44.26"
    form.longitudeText = "-72.58"
    await form.deriveClimate()

    #expect(form.zoneText == "7")
    #expect(form.lastFrostMonth == 4)
    #expect(form.climateSuggestions == [.zone, .lastFrost])
    #expect(form.derivedPrefilled == [.firstFrost])
    #expect(form.firstFrostMonth == 10)

    form.applySuggestion(.zone)
    #expect(form.zoneText == "5")
    #expect(form.climateSuggestions == [.lastFrost])

    form.applySuggestion(.lastFrost)
    #expect(form.lastFrostMonth == 5)
    #expect(form.lastFrostDay == 5)
    #expect(form.climateSuggestions.isEmpty)
}

@Test @MainActor func aFailedResolveLeavesManualEntryWorking() async throws {
    var search = StubAddressSearch()
    search.resolved = nil
    let form = try makeForm(search: search)
    form.load()
    form.addressQuery = "Nowhere"
    await form.searchAddresses()
    await form.selectSuggestion(form.addressSuggestions[0])

    #expect(form.latitudeText.isEmpty)
    #expect(form.addressMessage != nil)
    form.latitudeText = "10"
    form.longitudeText = "10"
    #expect(form.save())
}

@Test @MainActor func aFailedMinimaFetchIsSilent() async throws {
    let form = try makeForm(series: nil)
    form.load()
    form.latitudeText = "44.26"
    form.longitudeText = "-72.58"
    await form.deriveClimate()

    #expect(form.derivedClimate == nil)
    #expect(form.derivedPrefilled.isEmpty)
    #expect(form.zoneText.isEmpty)
    #expect(form.save())
}

@Test @MainActor func derivationIsCachedPerCoordinate() async throws {
    let counter = MinimaCounter()
    let suite = UUID().uuidString
    let form = try makeForm(counter: counter, suite: suite)
    form.load()
    form.latitudeText = "44.26"
    form.longitudeText = "-72.58"
    await form.deriveClimate()
    #expect(counter.count == 1)

    let second = try makeForm(counter: counter, suite: suite)
    second.load()
    second.latitudeText = "44.26"
    second.longitudeText = "-72.58"
    await second.deriveClimate()
    #expect(counter.count == 1)
    #expect(second.zoneText == "5")
}

@Test @MainActor func currentLocationFillsTheAddressAndDerives() async throws {
    let form = try makeForm(
        fillCoordinate: { vermont },
        reverseGeocode: { _ in
            ResolvedPlace(name: "Montpelier, Vermont", coordinate: vermont)
        }
    )
    form.load()
    await form.useCurrentLocation()

    #expect(form.latitudeText == "44.26000")
    #expect(form.longitudeText == "-72.58000")
    #expect(form.addressQuery == "Montpelier, Vermont")
    #expect(form.addressMessage == nil)
    #expect(form.derivedPrefilled == [.zone, .lastFrost, .firstFrost])
    #expect(form.zoneText == "5")
    #expect(form.lastFrostMonth == 5)
    #expect(form.firstFrostMonth == 10)
}

@Test @MainActor func currentLocationWithoutAnAddressKeepsCoordinatesAndSaysSo() async throws {
    struct NoAddress: Error {}
    let form = try makeForm(
        fillCoordinate: { vermont },
        reverseGeocode: { _ in throw NoAddress() }
    )
    form.load()
    await form.useCurrentLocation()

    #expect(form.latitudeText == "44.26000")
    #expect(form.longitudeText == "-72.58000")
    #expect(form.addressQuery.isEmpty)
    #expect(form.addressMessage != nil)
    #expect(form.zoneText == "5")
    #expect(form.derivedPrefilled == [.zone, .lastFrost, .firstFrost])
}

@Test @MainActor func aNoFrostClimateOffersOnlyTheZone() async throws {
    let subtropical = [
        DailyMinimum(date: day(2023, 1, 10), celsius: 8),
        DailyMinimum(date: day(2024, 1, 12), celsius: 10),
    ]
    let form = try makeForm(series: subtropical)
    form.load()
    form.latitudeText = "27.9"
    form.longitudeText = "-82.5"
    await form.deriveClimate()

    #expect(form.derivedPrefilled == [.zone])
    #expect(form.lastFrostMonth == nil)
    #expect(form.firstFrostMonth == nil)
    #expect(form.climateSuggestions.isEmpty)
}
