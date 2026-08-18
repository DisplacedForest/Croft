import Domain
import Foundation
import GRDB
import Graph

struct ObservationRecord: Codable, FetchableRecord, PersistableRecord, GraphEntity {
    static let databaseTableName = "observation"
    static var entityType: EntityType { .observation }

    var id: String
    var plantingID: String?
    var cultivarID: String?
    var speciesID: String?
    var bedID: String?
    var gardenID: String?
    var observedAt: Date
    var notes: String?
    var stage: String?
    var symptoms: String
    var measurements: String
    var tags: String

    var entityID: String { id }

    func targetRef() throws -> EntityRef {
        switch try target() {
        case .planting(let planting):
            EntityRef(id: planting.rawValue, type: .planting)
        case .plant(.cultivar(let cultivar)):
            EntityRef(id: cultivar.rawValue, type: .plant)
        case .plant(.species(let species)):
            EntityRef(id: species.rawValue, type: .plant)
        case .bed(let bed):
            EntityRef(id: bed.rawValue, type: .bed)
        case .garden(let garden):
            EntityRef(id: garden.rawValue, type: .garden)
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case plantingID = "planting_id"
        case cultivarID = "cultivar_id"
        case speciesID = "species_id"
        case bedID = "bed_id"
        case gardenID = "garden_id"
        case observedAt = "observed_at"
        case notes
        case stage
        case symptoms
        case measurements
        case tags
    }

    init(_ observation: Observation) throws {
        id = observation.id.rawValue
        plantingID = nil
        cultivarID = nil
        speciesID = nil
        bedID = nil
        gardenID = nil
        switch observation.target {
        case .planting(let planting):
            plantingID = planting.rawValue
        case .plant(.cultivar(let cultivar)):
            cultivarID = cultivar.rawValue
        case .plant(.species(let species)):
            speciesID = species.rawValue
        case .bed(let bed):
            bedID = bed.rawValue
        case .garden(let garden):
            gardenID = garden.rawValue
        }
        observedAt = observation.observedAt
        notes = observation.notes
        stage = observation.stage?.rawValue
        symptoms = try TaxonomyCoding.encodeList(observation.symptoms)
        measurements = try TaxonomyCoding.encodeList(observation.measurements)
        tags = try TaxonomyCoding.encodeList(observation.tags)
    }

    func model(photos: [String] = []) throws -> Observation {
        let decoder = TaxonomyRowDecoder(table: Self.databaseTableName)
        return Observation(
            id: Observation.ID(rawValue: id),
            target: try target(),
            observedAt: observedAt,
            notes: notes,
            stage: try decoder.enumValue(LifecycleStage.self, from: stage, column: "stage"),
            symptoms: try decoder.stringList(from: symptoms, column: "symptoms"),
            measurements: try measurementList(),
            tags: try decoder.stringList(from: tags, column: "tags"),
            photos: photos
        )
    }

    private func target() throws -> ObservationTarget {
        let targets: [ObservationTarget] = [
            plantingID.map { .planting(Planting.ID(rawValue: $0)) },
            cultivarID.map { .plant(.cultivar(Cultivar.ID(rawValue: $0))) },
            speciesID.map { .plant(.species(Species.ID(rawValue: $0))) },
            bedID.map { .bed(Bed.ID(rawValue: $0)) },
            gardenID.map { .garden(Garden.ID(rawValue: $0)) },
        ].compactMap { $0 }
        guard targets.count == 1, let target = targets.first else {
            throw ObservationError.malformedTarget(id)
        }
        return target
    }

    private func measurementList() throws -> [ObservationMeasurement] {
        do {
            return try TaxonomyCoding.decodeList(ObservationMeasurement.self, from: measurements)
        } catch {
            throw TaxonomyCodingError.malformedList(
                table: Self.databaseTableName, column: "measurements")
        }
    }
}

struct ObservationPhotoRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "observation_photo"

    var id: String
    var observationID: String
    var relativePath: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case observationID = "observation_id"
        case relativePath = "relative_path"
        case createdAt = "created_at"
    }
}
