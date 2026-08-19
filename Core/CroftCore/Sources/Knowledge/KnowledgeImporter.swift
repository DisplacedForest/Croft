import Domain
import Foundation
import GRDB
import Graph
import Persistence

public enum ImportError: Error, Equatable {
    case missingInput(String)
    case unpinnedInput(String)
    case checksumMismatch(file: String, expected: String, actual: String)
    case undecodableInput(file: String, detail: String)
    case unknownCrop(record: String, crop: String)
    case invalidLocalizedName(detail: String)
    case unknownReference(record: String, reference: String)
    case duplicateRecord(String)
    case unmappableValue(record: String, field: String, value: String)
    case missingImageDirectory(String)
    case missingImageFile(String)
    case unknownImageOwner(file: String, slug: String)
    case invalidImageField(slug: String, field: String)
    case disallowedImageLicense(slug: String, license: String)
    case orphanImageFile(String)
    case disallowedImageKind(slug: String, kind: String)
    case imageKindOwnerMismatch(slug: String, kind: String, ownerKind: String)
    case unexpectedRelatedSlug(slug: String, kind: String)
    case missingRelatedSlug(slug: String, kind: String)
    case unknownImageRelation(slug: String, relatedSlug: String)
    case unrelatedImageHost(slug: String, relatedSlug: String)
}

public struct ImportSummary: Equatable, Sendable {
    public var counts: [String: Int] = [:]
    public var skips: [String: Int] = [:]
    public var normalizations: [String: Int] = [:]

    mutating func count(_ key: String, by amount: Int = 1) {
        counts[key, default: 0] += amount
    }

    mutating func skip(_ key: String, by amount: Int = 1) {
        skips[key, default: 0] += amount
    }

    mutating func normalize(_ key: String, by amount: Int = 1) {
        normalizations[key, default: 0] += amount
    }
}

public struct KnowledgeImporter {
    public static let cropProfilesFile = "crop-profiles.json"
    public static let catalogFile = "cultivar-catalog.sanitized.json"
    public static let pestDiseaseFile = "pest-disease-cultivar-seed.sanitized.json"
    public static let plantImagesFile = "plant-images.json"
    public static let localizedNamesFile = "british-common-names.json"
    public static let importerVersion = "1"
    public static let requiredInputs = [cropProfilesFile, catalogFile, pestDiseaseFile]
    public static let optionalInputs = [plantImagesFile, localizedNamesFile]

    let inputDirectory: URL
    let imagesDirectory: URL?

    public init(inputDirectory: URL, imagesDirectory: URL? = nil) {
        self.inputDirectory = inputDirectory
        self.imagesDirectory = imagesDirectory
    }

    public func buildSnapshot(at output: URL) throws -> ImportSummary {
        let inputs = try loadInputs()
        do {
            return try write(inputs, to: output)
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
    }

    struct Inputs {
        let profiles: CropProfilesFile
        let catalog: CatalogFile
        let pestDisease: PestDiseaseFile
        let images: PlantImagesFile?
        let localizedNames: LocalizedNamesFile?
        let checksums: [String: String]
    }

    func loadInputs() throws -> Inputs {
        let lock = try InputsLock.load(from: inputDirectory)
        var checksums: [String: String] = [:]

        func read(_ name: String) throws -> Data {
            let url = inputDirectory.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url) else {
                throw ImportError.missingInput(name)
            }
            try lock.verify(fileName: name, data: data)
            checksums[name] = InputsLock.checksum(of: data)
            return data
        }

        func decode<Value: Decodable>(_ type: Value.Type, _ name: String) throws -> Value {
            do {
                return try JSONDecoder().decode(type, from: try read(name))
            } catch let error as ImportError {
                throw error
            } catch {
                throw ImportError.undecodableInput(file: name, detail: "\(error)")
            }
        }

        let profiles = try decode(CropProfilesFile.self, Self.cropProfilesFile)
        let catalog = try decode(CatalogFile.self, Self.catalogFile)
        let pestDisease = try decode(PestDiseaseFile.self, Self.pestDiseaseFile)
        var images: PlantImagesFile?
        if imageManifestExists {
            let manifest = try decode(PlantImagesFile.self, Self.plantImagesFile)
            try verifyImageFiles(manifest)
            images = manifest
        }
        var localizedNames: LocalizedNamesFile?
        let localizedPath = inputDirectory.appendingPathComponent(Self.localizedNamesFile).path
        if FileManager.default.fileExists(atPath: localizedPath) {
            let file = try decode(LocalizedNamesFile.self, Self.localizedNamesFile)
            try Self.validate(localizedNames: file, against: profiles)
            localizedNames = file
        }
        return Inputs(
            profiles: profiles,
            catalog: catalog,
            pestDisease: pestDisease,
            images: images,
            localizedNames: localizedNames,
            checksums: checksums
        )
    }

    static func validate(
        localizedNames file: LocalizedNamesFile,
        against profiles: CropProfilesFile
    ) throws {
        let slugs = Set(profiles.crops.map(\.crop))
        var seen = Set<String>()
        for entry in file.names {
            guard slugs.contains(entry.crop) else {
                throw ImportError.invalidLocalizedName(detail: "unknown crop slug \(entry.crop)")
            }
            guard entry.locale.range(of: "^[a-z]{2}-[A-Z]{2}$", options: .regularExpression) != nil
            else {
                throw ImportError.invalidLocalizedName(
                    detail: "malformed locale tag \(entry.locale) for \(entry.crop)")
            }
            guard !entry.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ImportError.invalidLocalizedName(detail: "empty name for \(entry.crop)")
            }
            guard !entry.citations.isEmpty else {
                throw ImportError.invalidLocalizedName(
                    detail: "missing citations for \(entry.crop)")
            }
            guard seen.insert("\(entry.crop)|\(entry.locale)").inserted else {
                throw ImportError.invalidLocalizedName(
                    detail: "duplicate entry \(entry.crop) \(entry.locale)")
            }
        }
    }

    private func write(_ inputs: Inputs, to output: URL) throws -> ImportSummary {
        var summary = ImportSummary()
        let mapped = try KnowledgeMapper(inputs: inputs).map(into: &summary)

        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: output.path) {
            try FileManager.default.removeItem(at: output)
        }
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        let queue = try DatabaseQueue(path: output.path, configuration: configuration)
        let database = try AppDatabase(queue, recordingChanges: false)

        try insertRecords(mapped, into: database)
        try queue.write { db in
            for ref in mapped.plantRefs {
                try GraphStore.register(ref, in: db)
            }
            for edge in mapped.edges {
                try GraphStore.relate(
                    from: edge.source,
                    edge.type,
                    to: edge.target,
                    provenance: edge.provenance,
                    edgeID: edge.id,
                    in: db
                )
            }
            try KnowledgeSnapshotTables.create(in: db)
            try KnowledgeSnapshotTables.writeMeta(
                mapped.meta(checksums: inputs.checksums), in: db)
            try KnowledgeSnapshotTables.writeAttributions(mapped.attributions, in: db)
            try KnowledgeSnapshotTables.writeImages(mapped.images, in: db)
        }
        try queue.vacuum()

        annotate(&summary, with: mapped)
        return summary
    }

    private func insertRecords(_ mapped: MappedKnowledge, into database: AppDatabase) throws {
        let families = PlantFamilyRepository(database)
        let genera = GenusRepository(database)
        let species = SpeciesRepository(database)
        let cultivars = CultivarRepository(database)
        let pests = PestRepository(database)
        let diseases = DiseaseRepository(database)
        let pathogens = PathogenRepository(database)
        for family in mapped.families {
            try families.insert(family)
        }
        for genus in mapped.genera {
            try genera.insert(genus)
        }
        for plant in mapped.species {
            try species.insert(plant)
        }
        for cultivar in mapped.cultivars {
            try cultivars.insert(cultivar)
        }
        for pest in mapped.pests {
            try pests.insert(pest)
        }
        for pathogen in mapped.pathogens {
            try pathogens.insert(pathogen)
        }
        for disease in mapped.diseases {
            try diseases.insert(disease)
        }
    }

    private func annotate(_ summary: inout ImportSummary, with mapped: MappedKnowledge) {
        summary.count("families", by: mapped.families.count)
        summary.count("genera", by: mapped.genera.count)
        summary.count("species", by: mapped.species.count)
        summary.count("cultivars", by: mapped.cultivars.count)
        summary.count("pests", by: mapped.pests.count)
        summary.count("diseases", by: mapped.diseases.count)
        summary.count("pathogens", by: mapped.pathogens.count)
        summary.count("edges", by: mapped.edges.count)
        summary.count("attributions", by: mapped.attributions.count)
        summary.count("images", by: mapped.images.count)
    }
}

struct PlannedEdge {
    let id: String
    let source: EntityRef
    let type: RelationshipType
    let target: EntityRef
    let provenance: Provenance
}

struct MappedKnowledge {
    var families: [PlantFamily] = []
    var genera: [Genus] = []
    var species: [Species] = []
    var cultivars: [Cultivar] = []
    var pests: [Pest] = []
    var diseases: [Disease] = []
    var pathogens: [Pathogen] = []
    var plantRefs: [EntityRef] = []
    var edges: [PlannedEdge] = []
    var attributions: [(recordID: String, citation: String)] = []
    var images: [MappedImage] = []
    var inputVersions: [String: String] = [:]
    var inputProvenance: [String: String] = [:]

    func meta(checksums: [String: String]) -> [String: String] {
        var meta: [String: String] = [:]
        meta["importer_version"] = KnowledgeImporter.importerVersion
        meta["schema_migration_head"] = SchemaMigrations.identifiers.last ?? ""
        let versions = inputVersions.sorted { $0.key < $1.key }
            .map { "\($0.key)@\($0.value)" }
            .joined(separator: "+")
        meta["snapshot_version"] = "\(versions)#importer\(KnowledgeImporter.importerVersion)"
        for (file, checksum) in checksums {
            meta["input_sha256:\(file)"] = checksum
        }
        for (name, provenance) in inputProvenance {
            meta["input_provenance:\(name)"] = provenance
        }
        return meta
    }
}
