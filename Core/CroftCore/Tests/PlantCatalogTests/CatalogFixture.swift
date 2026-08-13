import Domain
import Foundation
import GRDB
import Graph
import Persistence
import PlantCatalog
import Testing

let solanaceae = PlantFamily(name: "Solanaceae")
let solanum = Genus(familyID: solanaceae.id, name: "Solanum")
let lamiaceae = PlantFamily(name: "Lamiaceae")
let ocimum = Genus(familyID: lamiaceae.id, name: "Ocimum")

let tomato = Species(
    genusID: solanum.id,
    scientificName: "Solanum lycopersicum",
    commonNames: ["Tomato", "Love Apple"],
    lifeCycle: .annual,
    growthHabit: .vine,
    sunExposure: .fullSun,
    waterNeed: .moderate,
    soilPH: 6.0...6.8,
    spacingCentimeters: 45...60,
    daysToMaturity: 60...85,
    frostTolerance: .tender,
    harvestableParts: [.fruit]
)

let basil = Species(
    genusID: ocimum.id,
    scientificName: "Ocimum basilicum",
    commonNames: ["Basil"],
    lifeCycle: .annual,
    sunExposure: .fullSun,
    waterNeed: .moderate
)

let brandywine = Cultivar(
    speciesID: tomato.id,
    name: "Brandywine",
    daysToMaturity: 85...100,
    heirloom: true
)

let hornworm = Pest(
    commonName: "Tomato Hornworm",
    scientificName: "Manduca quinquemaculata",
    organismType: .pest,
    affectedPlantParts: [.leaf, .fruit],
    typicalDamage: "Defoliation and scarred fruit"
)

let ladybird = Pest(
    commonName: "Ladybird Beetle",
    organismType: .beneficial
)

let earlyBlight = Disease(
    name: "Early Blight",
    pathogen: "Alternaria solani",
    pathogenType: .fungal,
    symptoms: "Concentric leaf spots and stem lesions",
    affectedPlantParts: [.leaf, .stem]
)

let homeProperty = Property(name: "Home")
let kitchenGarden = Garden(name: "Kitchen Garden")
let polytunnel = GrowingArea(name: "Polytunnel")
let longBed = Bed(name: "Long Bed", kind: .raised)
let tunnelBed = Bed(name: "Tunnel Bed", kind: .inGround)

struct CatalogFixture {
    let database: AppDatabase
    let loader: PlantPageLoader
    let families: PlantFamilyRepository
    let genera: GenusRepository
    let species: SpeciesRepository
    let cultivars: CultivarRepository
    let pests: PestRepository
    let diseases: DiseaseRepository
    let structures: GardenStructureRepository
    let plantings: PlantingRepository

    static let plantingDate = Date(timeIntervalSince1970: 1_715_000_000)
    static let transplantDate = Date(timeIntervalSince1970: 1_717_000_000)
    static let endDate = Date(timeIntervalSince1970: 1_719_000_000)

    init() throws {
        database = try AppDatabase.inMemory()
        loader = PlantPageLoader(database)
        families = PlantFamilyRepository(database)
        genera = GenusRepository(database)
        species = SpeciesRepository(database)
        cultivars = CultivarRepository(database)
        pests = PestRepository(database)
        diseases = DiseaseRepository(database)
        structures = GardenStructureRepository(database)
        plantings = PlantingRepository(database)

        try families.insert(solanaceae)
        try families.insert(lamiaceae)
        try genera.insert(solanum)
        try genera.insert(ocimum)
        try species.insert(tomato)
        try species.insert(basil)
        try cultivars.insert(brandywine)
        try pests.insert(hornworm)
        try pests.insert(ladybird)
        try diseases.insert(earlyBlight)
        try structures.create(homeProperty)
        try structures.create(kitchenGarden, in: homeProperty.id)
        try structures.create(polytunnel, in: kitchenGarden.id)
        try structures.create(longBed, in: .garden(kitchenGarden.id))
        try structures.create(tunnelBed, in: .growingArea(polytunnel.id))
        try relate(
            plantRef(tomato.id.rawValue), .hostOf,
            EntityRef(id: hornworm.id.rawValue, type: .pest))
        try relate(
            plantRef(tomato.id.rawValue), .susceptibleTo,
            EntityRef(id: earlyBlight.id.rawValue, type: .disease))
    }

    func createImageTable() throws {
        try database.writer.write { db in
            try db.execute(
                sql: """
                    CREATE TABLE IF NOT EXISTS knowledge_image (
                        owner_kind TEXT NOT NULL,
                        owner_id TEXT NOT NULL,
                        related_id TEXT,
                        kind TEXT NOT NULL,
                        file TEXT NOT NULL,
                        sha256 TEXT NOT NULL,
                        license TEXT NOT NULL,
                        license_url TEXT,
                        artist TEXT,
                        source_page_url TEXT NOT NULL,
                        source_file_url TEXT NOT NULL,
                        PRIMARY KEY (owner_kind, owner_id, kind, file)
                    )
                    """
            )
        }
    }

    func insertImage(
        ownerKind: String,
        ownerID: String,
        file: String,
        kind: String = "catalog",
        relatedID: String? = nil,
        license: String = "CC BY 2.0",
        licenseURL: String? = "https://creativecommons.org/licenses/by/2.0/",
        artist: String? = "A Photographer"
    ) throws {
        try createImageTable()
        try database.writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO knowledge_image (
                        owner_kind, owner_id, related_id, kind, file, sha256,
                        license, license_url, artist, source_page_url, source_file_url
                    ) VALUES (?, ?, ?, ?, ?, 'abc', ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    ownerKind, ownerID, relatedID, kind, file, license, licenseURL, artist,
                    "https://example.org/wiki/\(file)", "https://example.org/files/\(file)",
                ]
            )
        }
    }

    func plantRef(_ id: String) -> EntityRef {
        EntityRef(id: id, type: .plant)
    }

    func relate(
        _ source: EntityRef,
        _ type: RelationshipType,
        _ target: EntityRef
    ) throws {
        try database.writer.write { db in
            _ = try GraphStore.relate(from: source, type, to: target, in: db)
        }
    }
}
