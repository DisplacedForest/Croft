public enum MigrationError: Error, Equatable {
    case unknownApplied([String])
    case appliedOutOfOrder(expected: [String], applied: [String])
}

enum MigrationHistory {
    static func validate(applied: Set<String>, registered: [String]) throws {
        let unknown = applied.subtracting(registered).sorted()
        guard unknown.isEmpty else {
            throw MigrationError.unknownApplied(unknown)
        }
        let expected = Array(registered.prefix(applied.count))
        guard applied == Set(expected) else {
            throw MigrationError.appliedOutOfOrder(expected: expected, applied: applied.sorted())
        }
    }
}
