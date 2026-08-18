import CoreLocation
import Foundation
import WeatherKit

import struct Domain.DailyMinimum

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

    public func todaySummary(at location: GeoLocation) async throws -> DailyWeatherSummary {
        let place = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let daily = try await WeatherService.shared.weather(for: place, including: .daily)
        let calendar = Calendar.current
        let today =
            daily.first { calendar.isDateInToday($0.date) }
            ?? daily.forecast.first
        guard let today else {
            throw WeatherSummaryFailure.noDailyForecast
        }
        return DailyWeatherSummary(
            highCelsius: today.highTemperature.converted(to: .celsius).value,
            lowCelsius: today.lowTemperature.converted(to: .celsius).value,
            precipitationMillimeters: today.precipitationAmount.converted(to: .millimeters).value
        )
    }
}

extension SystemWeatherProvider: HistoricalMinimaProviding {
    public func dailyMinima(
        at location: GeoLocation,
        from start: Date,
        to end: Date
    ) async throws -> [DailyMinimum] {
        let place = CLLocation(latitude: location.latitude, longitude: location.longitude)
        var minima: [DailyMinimum] = []
        var chunkStart = start
        let calendar = Calendar(identifier: .gregorian)
        while chunkStart < end {
            let chunkEnd = Swift.min(
                calendar.date(byAdding: .year, value: 1, to: chunkStart) ?? end, end)
            let daily = try await WeatherService.shared.weather(
                for: place,
                including: .daily(startDate: chunkStart, endDate: chunkEnd)
            )
            minima += daily.forecast.map { day in
                DailyMinimum(
                    date: day.date,
                    celsius: day.lowTemperature.converted(to: .celsius).value
                )
            }
            chunkStart = chunkEnd
        }
        return minima
    }
}

enum WeatherSummaryFailure: Error {
    case noDailyForecast
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
