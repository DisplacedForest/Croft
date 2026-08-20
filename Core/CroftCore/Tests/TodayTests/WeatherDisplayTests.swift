import Foundation
import Testing

@testable import Today

struct WeatherDisplayTests {
    private let unitedStates = Locale(identifier: "en_US")
    private let germany = Locale(identifier: "de_DE")

    private func formatted(
        _ value: Double,
        unit: UnitTemperature,
        locale: Locale,
        width: Measurement<UnitTemperature>.FormatStyle.UnitWidth = .abbreviated
    ) -> String {
        Measurement(value: value, unit: unit)
            .formatted(WeatherDisplay.temperatureStyle(width: width).locale(locale))
    }

    @Test func theObservedRawPrecisionCaseRendersWholeDegrees() {
        let rendered = formatted(72.748449, unit: .fahrenheit, locale: unitedStates)
        #expect(rendered.contains("73"))
        #expect(rendered.contains("°F"))
        #expect(!rendered.contains("."))
    }

    @Test func imperialLocaleConvertsCelsiusAndRoundsWholeDegrees() {
        let rendered = formatted(22.638, unit: .celsius, locale: unitedStates)
        #expect(rendered.contains("73"))
        #expect(rendered.contains("°F"))
        #expect(!rendered.contains("."))
    }

    @Test func metricLocaleKeepsCelsiusWholeDegrees() {
        let rendered = formatted(22.638, unit: .celsius, locale: germany)
        #expect(rendered.contains("23"))
        #expect(rendered.contains("°C"))
        #expect(!rendered.contains(","))
    }

    @Test func halfDegreesRoundAwayFromZero() {
        #expect(formatted(72.5, unit: .fahrenheit, locale: unitedStates).contains("73"))
        #expect(formatted(22.5, unit: .celsius, locale: germany).contains("23"))
    }

    @Test func negativeHalfDegreesRoundAwayFromZero() {
        let rendered = formatted(-0.5, unit: .celsius, locale: germany)
        #expect(rendered.contains("1"))
        #expect(!rendered.contains("0,5"))
    }

    @Test func narrowWidthAlsoRendersWholeDegrees() {
        let rendered = formatted(
            72.748449, unit: .fahrenheit, locale: unitedStates, width: .narrow)
        #expect(rendered.contains("73"))
        #expect(!rendered.contains("."))
    }
}
