import Foundation
import Testing

@testable import Today

private struct StubLocationProvider: LocationProviding {
    let result: Result<GeoLocation, Error>

    func currentLocation() async throws -> GeoLocation {
        try result.get()
    }
}

private struct StubWeatherProvider: WeatherProviding {
    let result: Result<WeatherSnapshot, Error>

    func currentWeather(at location: GeoLocation) async throws -> WeatherSnapshot {
        try result.get()
    }
}

private struct UnreachableWeatherProvider: WeatherProviding {
    func currentWeather(at location: GeoLocation) async throws -> WeatherSnapshot {
        Issue.record("weather provider must not be called when location fails")
        throw StubFailure.unexpected
    }
}

private enum StubFailure: Error {
    case unexpected
    case unavailable
}

private let snapshot = WeatherSnapshot(
    symbolName: "sun.max",
    conditionDescription: "Clear",
    temperature: Measurement(value: 21, unit: .celsius)
)

private let somewhere = GeoLocation(latitude: 45.5, longitude: -122.6)

@MainActor
private func makeModel(
    weather: any WeatherProviding,
    location: any LocationProviding
) -> TodayViewModel {
    TodayViewModel(weatherProvider: weather, locationProvider: location, now: .distantPast)
}

@Test @MainActor func startsInLoadingState() {
    let model = makeModel(
        weather: StubWeatherProvider(result: .success(snapshot)),
        location: StubLocationProvider(result: .success(somewhere))
    )
    #expect(model.weather == .loading)
}

@Test @MainActor func tickAdvancesTheClock() {
    let model = makeModel(
        weather: StubWeatherProvider(result: .success(snapshot)),
        location: StubLocationProvider(result: .success(somewhere))
    )
    let later = Date(timeIntervalSinceReferenceDate: 800_000_000)
    model.tick(to: later)
    #expect(model.now == later)
}

@Test @MainActor func loadWeatherPublishesTheSnapshot() async {
    let model = makeModel(
        weather: StubWeatherProvider(result: .success(snapshot)),
        location: StubLocationProvider(result: .success(somewhere))
    )
    await model.loadWeather()
    #expect(model.weather == .loaded(snapshot))
}

@Test @MainActor func weatherFailureDegradesToUnavailable() async {
    let model = makeModel(
        weather: StubWeatherProvider(result: .failure(StubFailure.unavailable)),
        location: StubLocationProvider(result: .success(somewhere))
    )
    await model.loadWeather()
    #expect(model.weather == .unavailable)
}

@Test @MainActor func locationFailureDegradesWithoutCallingWeather() async {
    let model = makeModel(
        weather: UnreachableWeatherProvider(),
        location: StubLocationProvider(result: .failure(StubFailure.unavailable))
    )
    await model.loadWeather()
    #expect(model.weather == .unavailable)
}

@Test @MainActor func reloadAfterFailureCanRecover() async {
    let failing = makeModel(
        weather: StubWeatherProvider(result: .failure(StubFailure.unavailable)),
        location: StubLocationProvider(result: .success(somewhere))
    )
    await failing.loadWeather()
    #expect(failing.weather == .unavailable)

    let recovering = makeModel(
        weather: StubWeatherProvider(result: .success(snapshot)),
        location: StubLocationProvider(result: .success(somewhere))
    )
    await recovering.loadWeather()
    #expect(recovering.weather == .loaded(snapshot))
}
