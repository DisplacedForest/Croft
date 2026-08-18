import Domain
import Foundation

public struct WeatherHistoryRecorder: Sendable {
    private let provider: any WeatherProviding
    private let store: any DailyWeatherWriting

    public init(provider: any WeatherProviding, store: any DailyWeatherWriting) {
        self.provider = provider
        self.store = store
    }

    public func recordToday(for property: Property, now: Date = Date()) async {
        guard let location = property.location else {
            return
        }
        let summary: DailyWeatherSummary
        do {
            summary = try await provider.todaySummary(
                at: GeoLocation(latitude: location.latitude, longitude: location.longitude))
        } catch {
            return
        }
        try? store.upsert(
            DailyWeather(
                propertyID: property.id,
                day: DayStamp(now),
                highCelsius: summary.highCelsius,
                lowCelsius: summary.lowCelsius,
                precipitationMillimeters: summary.precipitationMillimeters,
                provenance: .observed
            ))
    }
}
