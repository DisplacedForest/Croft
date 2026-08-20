import Domain
import Foundation
import Persistence

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write(
        Data("usage: walkthrough-seed <database-path> [--with-property]\n".utf8))
    exit(64)
}
let url = URL(fileURLWithPath: arguments[1])
let withProperty = arguments.contains("--with-property")

func refuse(_ reason: String) -> Never {
    FileHandle.standardError.write(Data((reason + "\n").utf8))
    exit(64)
}

let liveDirectory = try? FileManager.default
    .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    .appendingPathComponent("Croft", isDirectory: true)
    .resolvingSymlinksInPath()

func refersToLiveDirectory(_ candidate: URL) -> Bool {
    guard let liveDirectory else {
        return false
    }
    let resolved = candidate.resolvingSymlinksInPath()
    if resolved.path == liveDirectory.path {
        return true
    }
    guard
        let candidateIdentity = try? resolved.resourceValues(
            forKeys: [.fileResourceIdentifierKey]
        ).fileResourceIdentifier,
        let liveIdentity = try? liveDirectory.resourceValues(
            forKeys: [.fileResourceIdentifierKey]
        ).fileResourceIdentifier
    else {
        return false
    }
    return candidateIdentity.isEqual(liveIdentity)
}

var targetIsDirectory: ObjCBool = false
let targetExists = FileManager.default.fileExists(
    atPath: url.path, isDirectory: &targetIsDirectory)
if targetExists, targetIsDirectory.boolValue {
    refuse("refusing to seed: the target path is a directory")
}
if refersToLiveDirectory(url) || refersToLiveDirectory(url.deletingLastPathComponent()) {
    refuse("refusing to seed inside the live Croft support directory")
}

try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
for suffix in ["", "-wal", "-shm", ".pre-migration"] {
    try? FileManager.default.removeItem(atPath: url.path + suffix)
}

let database = try AppDatabase.open(at: url)
let structure = GardenStructureRepository(database)

let property =
    withProperty
    ? Property(
        name: "Home",
        location: GeoCoordinate(latitude: 44.98, longitude: -93.26),
        hardinessZone: HardinessZone(number: 5),
        lastFrost: MonthDay(month: 5, day: 10),
        firstFrost: MonthDay(month: 10, day: 1)
    )
    : Property(name: "Home")
try structure.create(property)

let garden = Garden(name: "Kitchen Garden")
try structure.create(garden, in: property.id)
let northBed = Bed(name: "North Bed", kind: .raised)
let southBed = Bed(name: "South Bed", kind: .raised)
try structure.create(northBed, in: .garden(garden.id))
try structure.create(southBed, in: .garden(garden.id))

let family = PlantFamily(name: "Solanaceae")
let genus = Genus(familyID: family.id, name: "Solanum")
let species = Species(
    genusID: genus.id,
    scientificName: "Solanum lycopersicum",
    commonNames: ["Tomato"]
)
let cultivar = Cultivar(
    speciesID: species.id,
    name: "Brandywine",
    daysToMaturity: 75...85
)
try PlantFamilyRepository(database).insert(family)
try GenusRepository(database).insert(genus)
try SpeciesRepository(database).insert(species)
try CultivarRepository(database).insert(cultivar)

let day: TimeInterval = 86_400
let plantings = PlantingRepository(database)

let lastSeason = Planting(
    identity: .cultivar(cultivar.id),
    bedID: northBed.id,
    plantedOn: Date(timeIntervalSinceNow: -400 * day),
    status: .finished,
    endedOn: Date(timeIntervalSinceNow: -300 * day)
)
try plantings.insert(lastSeason)
try HarvestRepository(database).insert(
    Harvest(
        plantingID: lastSeason.id,
        harvestedOn: Date(timeIntervalSinceNow: -305 * day),
        yield: .measured(try Quantity(amount: 2_400, unit: .gram)),
        harvestedPart: .fruit
    ))

let overdue = Planting(
    identity: .cultivar(cultivar.id),
    bedID: southBed.id,
    plantedOn: Date(timeIntervalSinceNow: -100 * day),
    status: .active
)
try plantings.insert(overdue)
let photos = PhotoStore(
    baseURL: url.deletingLastPathComponent().appendingPathComponent("Photos", isDirectory: true))
try ObservationRepository(database, photos: photos).insert(
    Observation(
        target: .planting(overdue.id),
        observedAt: Date(timeIntervalSinceNow: -93 * day),
        stage: .germinated
    ))

print(url.path)
