import Foundation
import Observation

public enum WeatherState: Sendable, Equatable {
    case loading
    case loaded(WeatherSnapshot)
    case unavailable
}

public enum ForecastState: Sendable, Equatable {
    case idle
    case loading
    case loaded([DayForecast])
    case unavailable
}

@MainActor
@Observable
public final class TodayViewModel {
    public private(set) var now: Date
    public private(set) var weather: WeatherState = .loading
    public private(set) var forecast: ForecastState = .idle

    private let weatherProvider: any WeatherProviding
    private let locationProvider: any LocationProviding
    private let forecastProvider: (any ForecastProviding)?
    private let calendar: Calendar
    private var forecastFetchedOn: Date?

    public init(
        weatherProvider: any WeatherProviding,
        locationProvider: any LocationProviding,
        forecastProvider: (any ForecastProviding)? = nil,
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        self.weatherProvider = weatherProvider
        self.locationProvider = locationProvider
        self.forecastProvider = forecastProvider
        self.calendar = calendar
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

    public func loadForecast(on date: Date = Date()) async {
        guard let forecastProvider else {
            forecast = .unavailable
            return
        }
        if case .loaded = forecast {
            if let fetched = forecastFetchedOn, calendar.isDate(fetched, inSameDayAs: date) {
                return
            }
        }
        forecast = .loading
        do {
            let location = try await locationProvider.currentLocation()
            let days = try await forecastProvider.dailyForecast(at: location)
            guard !days.isEmpty else {
                forecast = .unavailable
                return
            }
            forecast = .loaded(days)
            forecastFetchedOn = date
        } catch {
            forecast = .unavailable
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
