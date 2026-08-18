import Foundation

import struct Domain.LocalizedPlantName

public enum TaxonomyCodingError: Error, Equatable {
    case unreadableListEncoding
    case unknownRawValue(table: String, column: String, value: String)
    case invalidRange(table: String, column: String, lower: String?, upper: String?)
    case malformedList(table: String, column: String)
}

enum TaxonomyCoding {
    static func encodeList<Element: Encodable>(_ list: [Element]) throws -> String {
        let data = try JSONEncoder().encode(list)
        guard let text = String(bytes: data, encoding: .utf8) else {
            throw TaxonomyCodingError.unreadableListEncoding
        }
        return text
    }

    static func decodeList<Element: Decodable>(
        _ element: Element.Type,
        from text: String
    ) throws -> [Element] {
        try JSONDecoder().decode([Element].self, from: Data(text.utf8))
    }

    static func encodeCommonNames(
        plain: [String],
        localized: [LocalizedPlantName]
    ) throws -> String {
        let entries = plain.map(CommonNameEntry.plain) + localized.map(CommonNameEntry.localized)
        return try encodeList(entries)
    }

    static func bounds<Bound>(_ range: ClosedRange<Bound>?) -> (lower: Bound?, upper: Bound?) {
        guard let range else {
            return (nil, nil)
        }
        return (range.lowerBound, range.upperBound)
    }
}

struct TaxonomyRowDecoder {
    let table: String

    func enumValue<Value: RawRepresentable>(
        _ type: Value.Type,
        from raw: String?,
        column: String
    ) throws -> Value? where Value.RawValue == String {
        guard let raw else {
            return nil
        }
        return try requiredEnumValue(type, from: raw, column: column)
    }

    func enumValue<Value: RawRepresentable>(
        _ type: Value.Type,
        from raw: String,
        column: String
    ) throws -> Value where Value.RawValue == String {
        try requiredEnumValue(type, from: raw, column: column)
    }

    func enumList<Value: RawRepresentable>(
        _ type: Value.Type,
        from text: String,
        column: String
    ) throws -> [Value] where Value.RawValue == String {
        try stringList(from: text, column: column).map {
            try requiredEnumValue(type, from: $0, column: column)
        }
    }

    func stringList(from text: String, column: String) throws -> [String] {
        do {
            return try TaxonomyCoding.decodeList(String.self, from: text)
        } catch {
            throw TaxonomyCodingError.malformedList(table: table, column: column)
        }
    }

    func range<Bound: Comparable>(
        lower: Bound?,
        upper: Bound?,
        column: String
    ) throws -> ClosedRange<Bound>? {
        if lower == nil, upper == nil {
            return nil
        }
        guard let lower, let upper, lower <= upper else {
            throw TaxonomyCodingError.invalidRange(
                table: table,
                column: column,
                lower: lower.map { String(describing: $0) },
                upper: upper.map { String(describing: $0) }
            )
        }
        return lower...upper
    }

    private func requiredEnumValue<Value: RawRepresentable>(
        _ type: Value.Type,
        from raw: String,
        column: String
    ) throws -> Value where Value.RawValue == String {
        guard let value = Value(rawValue: raw) else {
            throw TaxonomyCodingError.unknownRawValue(table: table, column: column, value: raw)
        }
        return value
    }
}

enum CommonNameEntry: Codable, Equatable {
    case plain(String)
    case localized(LocalizedPlantName)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .plain(text)
        } else {
            self = .localized(try container.decode(LocalizedPlantName.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .plain(let text):
            try container.encode(text)
        case .localized(let name):
            try container.encode(name)
        }
    }
}

struct SplitCommonNames {
    let plain: [String]
    let localized: [LocalizedPlantName]
}

extension TaxonomyRowDecoder {
    func commonNames(from text: String, column: String) throws -> SplitCommonNames {
        let entries: [CommonNameEntry]
        do {
            entries = try TaxonomyCoding.decodeList(CommonNameEntry.self, from: text)
        } catch {
            throw TaxonomyCodingError.malformedList(table: table, column: column)
        }
        var plain: [String] = []
        var localized: [LocalizedPlantName] = []
        for entry in entries {
            switch entry {
            case .plain(let name):
                plain.append(name)
            case .localized(let name):
                localized.append(name)
            }
        }
        return SplitCommonNames(plain: plain, localized: localized)
    }
}
