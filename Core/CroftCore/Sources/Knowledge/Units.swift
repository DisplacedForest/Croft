import Foundation

public enum Units {
    public static func celsius(fromFahrenheit fahrenheit: Double) -> Double {
        ((fahrenheit - 32) * 5 / 9 * 10).rounded() / 10
    }

    public static func centimeters(fromInches inches: Double) -> Double {
        (inches * 2.54 * 10).rounded() / 10
    }

    public static func doubleRange(_ text: String?) -> ClosedRange<Double>? {
        guard let text, !text.contains(where: \.isLetter) else {
            return nil
        }
        return bounds(of: text)
    }

    public static func intRange(_ text: String?) -> ClosedRange<Int>? {
        guard let range = doubleRange(text) else {
            return nil
        }
        return Int(range.lowerBound)...Int(range.upperBound)
    }

    public static func celsiusRange(fromFahrenheit text: String?) -> ClosedRange<Double>? {
        guard let range = doubleRange(text) else {
            return nil
        }
        return celsius(fromFahrenheit: range.lowerBound)...celsius(fromFahrenheit: range.upperBound)
    }

    public static func centimeterRange(fromInches text: String?) -> ClosedRange<Double>? {
        guard let range = doubleRange(text) else {
            return nil
        }
        return centimeters(fromInches: range.lowerBound)...centimeters(fromInches: range.upperBound)
    }

    public static func centimeterRange(fromMeasurement text: String?) -> ClosedRange<Double>? {
        guard let text else {
            return nil
        }
        let lowered = text.lowercased()
        let known = ["inches", "inch", "in", "feet", "foot", "ft", "to", "th", "and"]
        let words = lowered.split(whereSeparator: { $0.isWhitespace }).flatMap {
            $0.split(separator: "-")
        }
        for word in words {
            let letters = word.filter(\.isLetter)
            if !letters.isEmpty && !known.contains(String(letters)) {
                return nil
            }
        }
        let factor: Double = lowered.contains("f") ? 12 : 1
        let stripped = String(lowered.map { $0.isLetter ? " " : $0 })
        guard let range = bounds(of: stripped) else {
            return nil
        }
        let lower = centimeters(fromInches: range.lowerBound * factor)
        let upper = centimeters(fromInches: range.upperBound * factor)
        return lower...upper
    }

    private static func bounds(of text: String) -> ClosedRange<Double>? {
        let values = numbers(in: text)
        guard let first = values.first, values.count <= 2 else {
            return nil
        }
        let last = values.count == 2 ? values[1] : first
        return first <= last ? first...last : nil
    }

    private static func numbers(in text: String) -> [Double] {
        var values: [Double] = []
        var current = ""

        func flush() {
            defer { current = "" }
            guard !current.isEmpty else {
                return
            }
            if let slash = current.firstIndex(of: "/") {
                let numerator = Double(current[..<slash])
                let denominator = Double(current[current.index(after: slash)...])
                if let numerator, let denominator, denominator != 0 {
                    values.append(numerator / denominator)
                }
                return
            }
            if let value = Double(current) {
                values.append(value)
            }
        }

        for character in text {
            if character.isNumber || character == "." || character == "/" {
                current.append(character)
            } else {
                flush()
            }
        }
        flush()
        return values
    }
}
