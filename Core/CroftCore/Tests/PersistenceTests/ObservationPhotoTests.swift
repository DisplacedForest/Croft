import Domain
import Foundation
import GRDB
import Graph
import Testing

@testable import Persistence

private let photoData = Data("pretend jpeg".utf8)
private let otherPhotoData = Data("another pretend jpeg".utf8)

struct ObservationPhotoTests {
    @Test func addingAPhotoWritesTheFileAndTheRow() throws {
        let fixture = try ObservationFixture()
        let observation = fixture.observation()
        try fixture.observations.insert(observation)
        let path = try fixture.observations.addPhoto(photoData, to: observation.id)
        #expect(path.hasPrefix("observations/\(observation.id.rawValue)/"))
        #expect(try fixture.fileExists(path))
        #expect(
            try Data(contentsOf: fixture.photos.url(forRelativePath: path)) == photoData)
        #expect(try fixture.photoRowCount(observation.id) == 1)
    }

    @Test func aFetchedObservationCarriesItsPhotos() throws {
        let fixture = try ObservationFixture()
        var observation = fixture.observation()
        try fixture.observations.insert(observation)
        #expect(try fixture.observations.fetch(id: observation.id)?.photos == [])
        let path = try fixture.observations.addPhoto(photoData, to: observation.id)
        observation.photos = [path]
        #expect(try fixture.observations.fetch(id: observation.id) == observation)
    }

    @Test func everyFetchPathCarriesPhotos() throws {
        let fixture = try ObservationFixture()
        let observation = fixture.observation()
        try fixture.observations.insert(observation)
        let path = try fixture.observations.addPhoto(photoData, to: observation.id)
        #expect(try fixture.observations.fetchAll().map(\.photos) == [[path]])
        #expect(try fixture.observations.recent(limit: 1).map(\.photos) == [[path]])
        #expect(
            try fixture.observations.observations(on: .bed(fixture.bed.id)).map(\.photos)
                == [[path]])
    }

    @Test func writingAnObservationIgnoresItsPhotosProperty() throws {
        let fixture = try ObservationFixture()
        var observation = fixture.observation()
        observation.photos = ["observations/ghost/made-up"]
        try fixture.observations.insert(observation)
        #expect(try fixture.observations.fetch(id: observation.id)?.photos == [])
        let path = try fixture.observations.addPhoto(photoData, to: observation.id)
        observation.photos = []
        try fixture.observations.update(observation)
        #expect(try fixture.observations.fetch(id: observation.id)?.photos == [path])
    }

    @Test func photosAreListedForTheirObservation() throws {
        let fixture = try ObservationFixture()
        let observation = fixture.observation()
        let other = fixture.observation(on: .garden(fixture.garden.id))
        try fixture.observations.insert(observation)
        try fixture.observations.insert(other)
        let first = try fixture.observations.addPhoto(photoData, to: observation.id)
        let second = try fixture.observations.addPhoto(otherPhotoData, to: observation.id)
        _ = try fixture.observations.addPhoto(photoData, to: other.id)
        #expect(try Set(fixture.observations.photos(for: observation.id)) == [first, second])
        #expect(try fixture.observations.photos(for: other.id).count == 1)
    }

    @Test func anObservationWithoutPhotosListsNone() throws {
        let fixture = try ObservationFixture()
        let observation = fixture.observation()
        try fixture.observations.insert(observation)
        #expect(try fixture.observations.photos(for: observation.id).isEmpty)
    }

    @Test func addingAPhotoToAMissingObservationThrows() throws {
        let fixture = try ObservationFixture()
        let ghost = Observation.ID(rawValue: "missing")
        #expect(throws: ObservationError.observationNotFound(ghost.rawValue)) {
            _ = try fixture.observations.addPhoto(photoData, to: ghost)
        }
    }

    @Test func deletingAnObservationRemovesItsPhotoRowsAndFiles() throws {
        let fixture = try ObservationFixture()
        let observation = fixture.observation()
        try fixture.observations.insert(observation)
        let path = try fixture.observations.addPhoto(photoData, to: observation.id)
        #expect(try fixture.observations.delete(id: observation.id))
        #expect(try fixture.photoRowCount(observation.id) == 0)
        #expect(try !fixture.fileExists(path))
    }

    @Test func aPhotoRowIsRemovedWithItsObservationRow() throws {
        let fixture = try ObservationFixture()
        let observation = fixture.observation()
        try fixture.observations.insert(observation)
        _ = try fixture.observations.addPhoto(photoData, to: observation.id)
        try fixture.database.writer.write { db in
            try db.execute(
                sql: "DELETE FROM observation WHERE id = ?", arguments: [observation.id.rawValue])
        }
        #expect(try fixture.photoRowCount(observation.id) == 0)
    }

    @Test func theSamePathCannotBeStoredTwice() throws {
        let fixture = try ObservationFixture()
        let observation = fixture.observation()
        try fixture.observations.insert(observation)
        let path = try fixture.observations.addPhoto(photoData, to: observation.id)
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO observation_photo
                            (id, observation_id, relative_path, created_at)
                        VALUES ('dup', ?, ?, '2024-07-03 12:00:00')
                        """,
                    arguments: [observation.id.rawValue, path]
                )
            }
        }
    }
}

struct ObservationPhotoSweepTests {
    @Test func aDeadObservationsDirectoryIsRemoved() throws {
        let fixture = try ObservationFixture()
        let kept = fixture.observation()
        let vanished = fixture.observation(on: .garden(fixture.garden.id))
        try fixture.observations.insert(kept)
        try fixture.observations.insert(vanished)
        let keptPath = try fixture.observations.addPhoto(photoData, to: kept.id)
        let orphanPath = try fixture.observations.addPhoto(otherPhotoData, to: vanished.id)
        try fixture.database.writer.write { db in
            try db.execute(
                sql: "DELETE FROM observation WHERE id = ?", arguments: [vanished.id.rawValue])
        }
        try fixture.observations.sweepOrphanedPhotos()
        #expect(try fixture.fileExists(keptPath))
        #expect(try !fixture.fileExists(orphanPath))
        #expect(
            !FileManager.default.fileExists(atPath: fixture.directory(for: vanished.id).path))
    }

    @Test func aStrayFileInALiveDirectoryIsSwept() throws {
        let fixture = try ObservationFixture()
        let observation = fixture.observation()
        try fixture.observations.insert(observation)
        let referenced = try fixture.observations.addPhoto(photoData, to: observation.id)
        let stray = try fixture.writeStrayFile(named: "leftover", for: observation.id)
        try fixture.observations.sweepOrphanedPhotos()
        #expect(try fixture.fileExists(referenced))
        #expect(!FileManager.default.fileExists(atPath: stray.path))
    }

    @Test func aLiveObservationWithoutRowsLosesEveryFile() throws {
        let fixture = try ObservationFixture()
        let observation = fixture.observation()
        try fixture.observations.insert(observation)
        let stray = try fixture.writeStrayFile(named: "leftover", for: observation.id)
        try fixture.observations.sweepOrphanedPhotos()
        #expect(!FileManager.default.fileExists(atPath: stray.path))
        #expect(
            FileManager.default.fileExists(atPath: fixture.directory(for: observation.id).path))
    }

    @Test func aLiveObservationIsNeverARemovalCandidate() throws {
        let fixture = try ObservationFixture()
        let observation = fixture.observation()
        try fixture.observations.insert(observation)
        _ = try fixture.observations.addPhoto(photoData, to: observation.id)
        let candidates = try fixture.photos.orphanedIdentifiers(keeping: [
            observation.id.rawValue
        ])
        #expect(candidates.isEmpty)
    }

    @Test func anObservationCreatedAfterTheSnapshotSurvivesTheSweep() throws {
        let fixture = try ObservationFixture()
        let latecomer = fixture.observation()
        try fixture.observations.insert(latecomer)
        let path = try fixture.observations.addPhoto(photoData, to: latecomer.id)
        let candidates = try fixture.photos.orphanedIdentifiers(keeping: [])
        #expect(candidates == [latecomer.id.rawValue])
        try fixture.observations.sweepOrphanedPhotos()
        #expect(try fixture.fileExists(path))
    }

    @Test func sweepingWithoutAPhotoDirectoryIsHarmless() throws {
        let fixture = try ObservationFixture()
        try fixture.observations.sweepOrphanedPhotos()
        #expect(!FileManager.default.fileExists(atPath: fixture.photoRoot.path))
    }

    @Test func removingPhotosForAnObservationWithoutAnyIsHarmless() throws {
        let fixture = try ObservationFixture()
        try fixture.photos.removePhotos(forObservation: Observation.ID(rawValue: "missing"))
    }
}

struct PhotoStorePathSafetyTests {
    @Test(arguments: ["../escape", "a/b", "", "..", "back\\slash"])
    func anUnsafeIdentifierIsRejectedOnAdd(raw: String) throws {
        let fixture = try ObservationFixture()
        #expect(throws: PhotoStoreError.invalidIdentifier(raw)) {
            _ = try fixture.photos.add(photoData, forObservation: Observation.ID(rawValue: raw))
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.photoRoot.path))
    }

    @Test(arguments: ["../escape", "a/b", "", "..", "back\\slash"])
    func anUnsafeIdentifierIsRejectedOnRemoval(raw: String) throws {
        let fixture = try ObservationFixture()
        #expect(throws: PhotoStoreError.invalidIdentifier(raw)) {
            try fixture.photos.removePhotos(forObservation: Observation.ID(rawValue: raw))
        }
    }

    @Test func anUnsafeIdentifierWritesNothingOutsideTheBaseDirectory() throws {
        let fixture = try ObservationFixture()
        let sibling = fixture.photoRoot.deletingLastPathComponent()
            .appendingPathComponent("escape", isDirectory: true)
        #expect(throws: PhotoStoreError.self) {
            _ = try fixture.photos.add(
                photoData, forObservation: Observation.ID(rawValue: "../escape"))
        }
        #expect(!FileManager.default.fileExists(atPath: sibling.path))
    }

    @Test(arguments: [
        "../outside", "observations/../../outside", "/absolute/path", "", "back\\slash",
    ])
    func anEscapingRelativePathIsRejected(path: String) throws {
        let fixture = try ObservationFixture()
        #expect(throws: PhotoStoreError.invalidRelativePath(path)) {
            _ = try fixture.photos.url(forRelativePath: path)
        }
    }

    @Test func aStoredEscapingPathIsRejectedBySweeping() throws {
        let fixture = try ObservationFixture()
        let observation = fixture.observation()
        try fixture.observations.insert(observation)
        try fixture.database.writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO observation_photo
                        (id, observation_id, relative_path, created_at)
                    VALUES ('p1', ?, '../outside', '2024-07-03 12:00:00')
                    """,
                arguments: [observation.id.rawValue]
            )
        }
        _ = try fixture.writeStrayFile(named: "leftover", for: observation.id)
        #expect(throws: PhotoStoreError.invalidRelativePath("../outside")) {
            try fixture.observations.sweepOrphanedPhotos()
        }
    }

    @Test func aSafeRelativePathResolvesUnderTheBaseDirectory() throws {
        let fixture = try ObservationFixture()
        let observation = fixture.observation()
        try fixture.observations.insert(observation)
        let path = try fixture.observations.addPhoto(photoData, to: observation.id)
        let url = try fixture.photos.url(forRelativePath: path)
        #expect(url.standardizedFileURL.path.hasPrefix(fixture.photoRoot.standardizedFileURL.path))
    }
}
