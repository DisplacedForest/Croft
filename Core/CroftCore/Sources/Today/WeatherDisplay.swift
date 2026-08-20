import Foundation

public enum WeatherDisplay {
    public static func temperatureStyle(
        width: Measurement<UnitTemperature>.FormatStyle.UnitWidth
    ) -> Measurement<UnitTemperature>.FormatStyle {
        .measurement(
            width: width,
            usage: .weather,
            numberFormatStyle: .number
                .precision(.fractionLength(0))
                .rounded(rule: .toNearestOrAwayFromZero)
        )
    }
}
