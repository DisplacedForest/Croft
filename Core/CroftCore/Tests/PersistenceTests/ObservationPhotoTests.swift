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
        #expect(fixture.fileExists(path))
        #expect(
            try Data(contentsOf: fixture.photos.url(forRelativePath: path)) == photoData)
        #expect(try fixture.photoRowCount(observation.id) == 1)
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
        #expect(!fixture.fileExists(path))
    }

    @Test func sweepingOrphansKeepsLivingObservations() throws {
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
        #expect(fixture.fileExists(keptPath))
        #expect(!fixture.fileExists(orphanPath))
    }

    @Test func sweepingOrphansWithoutAPhotoDirectoryIsHarmless() throws {
        let fixture = try ObservationFixture()
        try fixture.observations.sweepOrphanedPhotos()
        #expect(!FileManager.default.fileExists(atPath: fixture.photoRoot.path))
    }

    @Test func removingPhotosForAnObservationWithoutAnyIsHarmless() throws {
        let fixture = try ObservationFixture()
        try fixture.photos.removePhotos(forObservation: Observation.ID(rawValue: "missing"))
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
