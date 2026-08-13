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

public protocol LocationProviding: Sendable {
    func currentLocation() async throws -> GeoLocation
}

public protocol WeatherProviding: Sendable {
    func currentWeather(at location: GeoLocation) async throws -> WeatherSnapshot
}
