import CoreLocation
import Foundation
import WeatherKit

public struct SystemWeatherProvider: WeatherProviding, ForecastProviding {
    public init() {}

    public func currentWeather(at location: GeoLocation) async throws -> WeatherSnapshot {
        let place = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let current = try await WeatherService.shared.weather(for: place, including: .current)
        return WeatherSnapshot(
            symbolName: current.symbolName,
            conditionDescription: current.condition.description,
            temperature: current.temperature
        )
    }

    public func dailyForecast(at location: GeoLocation) async throws -> [DayForecast] {
        let place = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let daily = try await WeatherService.shared.weather(for: place, including: .daily)
        return daily.forecast.prefix(7).map { day in
            DayForecast(
                date: day.date,
                symbolName: day.symbolName,
                high: day.highTemperature,
                low: day.lowTemperature,
                precipitationChance: day.precipitationChance
            )
        }
    }
}

public struct SystemLocationProvider: LocationProviding {
    private let timeout: Duration

    public init(timeout: Duration = .seconds(15)) {
        self.timeout = timeout
    }

    public func currentLocation() async throws -> GeoLocation {
        try await withDeadline(timeout) {
            for try await update in CLLocationUpdate.liveUpdates() {
                if let location = update.location {
                    return GeoLocation(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                }
                if update.authorizationDenied || update.authorizationRestricted {
                    throw LocationFailure.denied
                }
            }
            throw LocationFailure.unavailable
        }
    }
}

enum LocationFailure: Error {
    case denied
    case unavailable
    case timedOut
}

private func withDeadline<T: Sendable>(
    _ limit: Duration,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(for: limit)
            throw LocationFailure.timedOut
        }
        guard let first = try await group.next() else {
            throw LocationFailure.unavailable
        }
        group.cancelAll()
        return first
    }
}
