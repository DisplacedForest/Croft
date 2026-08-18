import Persistence

enum ThreatNameIndex {
    static func names(from database: AppDatabase?) -> Set<String> {
        guard let database else {
            return []
        }
        var names: [String] = []
        if let pests = try? PestRepository(database).fetchAll() {
            names += pests.map(\.commonName)
        }
        if let diseases = try? DiseaseRepository(database).fetchAll() {
            names += diseases.map(\.name)
        }
        return Set(names)
    }
}
