import Foundation

enum TaxonomyCodingError: Error, Equatable {
    case unreadableListEncoding
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

    static func bounds<Bound>(_ range: ClosedRange<Bound>?) -> (lower: Bound?, upper: Bound?) {
        guard let range else {
            return (nil, nil)
        }
        return (range.lowerBound, range.upperBound)
    }

    static func range<Bound: Comparable>(lower: Bound?, upper: Bound?) -> ClosedRange<Bound>? {
        guard let lower, let upper, lower <= upper else {
            return nil
        }
        return lower...upper
    }
}
