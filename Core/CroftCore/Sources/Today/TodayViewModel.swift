import Foundation
import Observation

public enum WeatherState: Sendable, Equatable {
    case loading
    case loaded(WeatherSnapshot)
    case unavailable
}

@MainActor
@Observable
public final class TodayViewModel {
    public private(set) var now: Date
    public private(set) var weather: WeatherState = .loading

    private let weatherProvider: any WeatherProviding
    private let locationProvider: any LocationProviding

    public init(
        weatherProvider: any WeatherProviding,
        locationProvider: any LocationProviding,
        now: Date = Date()
    ) {
        self.weatherProvider = weatherProvider
        self.locationProvider = locationProvider
        self.now = now
    }

    public func tick(to date: Date) {
        now = date
    }

    public func loadWeather() async {
        weather = .loading
        do {
            let location = try await locationProvider.currentLocation()
            let snapshot = try await weatherProvider.currentWeather(at: location)
            weather = .loaded(snapshot)
        } catch {
            weather = .unavailable
        }
    }

    public func startClock(interval: Duration = .seconds(1)) async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: interval)
            } catch {
                return
            }
            now = Date()
        }
    }
}
