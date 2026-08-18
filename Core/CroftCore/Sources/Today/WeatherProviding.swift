import Foundation

public struct GeoLocation: Sendable, Equatable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct WeatherSnapshot: Sendable, Equatable {
    public let symbolName: String
    public let conditionDescription: String
    public let temperature: Measurement<UnitTemperature>

    public init(
        symbolName: String,
        conditionDescription: String,
        temperature: Measurement<UnitTemperature>
    ) {
        self.symbolName = symbolName
        self.conditionDescription = conditionDescription
        self.temperature = temperature
    }
}

public struct DayForecast: Sendable, Equatable {
    public let date: Date
    public let symbolName: String
    public let high: Measurement<UnitTemperature>
    public let low: Measurement<UnitTemperature>
    public let precipitationChance: Double

    public init(
        date: Date,
        symbolName: String,
        high: Measurement<UnitTemperature>,
        low: Measurement<UnitTemperature>,
        precipitationChance: Double
    ) {
        self.date = date
        self.symbolName = symbolName
        self.high = high
        self.low = low
        self.precipitationChance = precipitationChance
    }
}

public protocol LocationProviding: Sendable {
    func currentLocation() async throws -> GeoLocation
}

public protocol WeatherProviding: Sendable {
    func currentWeather(at location: GeoLocation) async throws -> WeatherSnapshot
}

public protocol ForecastProviding: Sendable {
    func dailyForecast(at location: GeoLocation) async throws -> [DayForecast]
}
