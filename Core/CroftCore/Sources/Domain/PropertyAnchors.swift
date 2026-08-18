public struct GeoCoordinate: Equatable, Hashable, Sendable, Codable {
    public let latitude: Double
    public let longitude: Double

    public init?(latitude: Double, longitude: Double) {
        guard (-90.0...90.0).contains(latitude), (-180.0...180.0).contains(longitude) else {
            return nil
        }
        self.latitude = latitude
        self.longitude = longitude
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        guard let coordinate = GeoCoordinate(latitude: latitude, longitude: longitude) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Coordinate out of range: \(latitude), \(longitude)"
                )
            )
        }
        self = coordinate
    }
}

public struct MonthDay: Equatable, Hashable, Sendable, Codable {
    public let month: Int
    public let day: Int

    private static let daysInMonth = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    public init?(month: Int, day: Int) {
        guard (1...12).contains(month), (1...MonthDay.daysInMonth[month - 1]).contains(day) else {
            return nil
        }
        self.month = month
        self.day = day
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let month = try container.decode(Int.self, forKey: .month)
        let day = try container.decode(Int.self, forKey: .day)
        guard let monthDay = MonthDay(month: month, day: day) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid month-day: \(month)-\(day)"
                )
            )
        }
        self = monthDay
    }

    public static func lastDay(ofMonth month: Int) -> Int? {
        guard (1...12).contains(month) else {
            return nil
        }
        return daysInMonth[month - 1]
    }
}

public enum PropertyAnchor: CaseIterable, Hashable, Sendable {
    case location
    case hardinessZone
    case frostDates
}

extension Property {
    public var hasFrostDates: Bool {
        lastFrost != nil && firstFrost != nil
    }

    public var missingAnchors: [PropertyAnchor] {
        var missing: [PropertyAnchor] = []
        if location == nil {
            missing.append(.location)
        }
        if hardinessZone == nil {
            missing.append(.hardinessZone)
        }
        if !hasFrostDates {
            missing.append(.frostDates)
        }
        return missing
    }
}
