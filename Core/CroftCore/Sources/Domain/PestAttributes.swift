public enum OrganismType: String, CaseIterable, Codable, Sendable {
    case pest
    case beneficial
}

public enum Season: String, CaseIterable, Codable, Sendable {
    case spring
    case summer
    case fall
    case winter
}

public enum PlantPart: String, CaseIterable, Codable, Sendable {
    case leaf
    case stem
    case root
    case tuber
    case bulb
    case fruit
    case seed
    case flower
}
