import Domain
import Foundation
import GRDB
import Graph
import Persistence
import Testing

@testable import Capture

struct LogObservationFormTests {
    private func planting(_ fixture: CaptureFixture) throws -> Planting {
        let planting = Planting(
            identity: .cultivar(fixture.cultivar.id), bedID: fixture.bed.id, status: .active)
        try fixture.context.plantings.insert(planting)
        return planting
    }

    @Test func anEmptyObservationIsRejected() throws {
        let fixture = try CaptureFixture()
        let target = ObservationTarget.planting(try planting(fixture).id)
        let form = LogObservationForm(context: fixture.context, target: target)
        #expect(!form.canSave)
        #expect(throws: CaptureValidationError.incomplete) {
            try form.save()
        }
        #expect(try fixture.context.observations.fetchAll().isEmpty)
    }

    @Test func aNoteOnlyObservationSavesAgainstItsTarget() throws {
        let fixture = try CaptureFixture()
        let plantingID = try planting(fixture).id
        let form = LogObservationForm(
            context: fixture.context, target: .planting(plantingID))
        form.notes = "first true leaves"
        let saved = try form.save()
        let fetched = try fixture.context.observations.fetch(id: saved.id)
        #expect(fetched?.notes == "first true leaves")
        #expect(fetched?.target == .planting(plantingID))
        #expect(fetched?.photos.isEmpty == true)
    }

    @Test func photosAttachThroughTheStore() throws {
        let fixture = try CaptureFixture()
        let form = LogObservationForm(
            context: fixture.context, target: .bed(fixture.bed.id))
        form.photos = [Data([0xFF, 0xD8, 0xFF, 0xE0]), Data([0x89, 0x50, 0x4E, 0x47])]
        let saved = try form.save()
        #expect(try fixture.context.observations.photos(for: saved.id).count == 2)
    }

    @Test func aPhotoFailureNeverDuplicatesTheObservationOnRetry() throws {
        let fixture = try CaptureFixture(brokenPhotoStore: true)
        let form = LogObservationForm(
            context: fixture.context, target: .bed(fixture.bed.id))
        form.notes = "hornworm frass on lower leaves"
        form.photos = [Data([0xFF, 0xD8])]
        #expect(throws: (any Error).self) {
            try form.save()
        }
        #expect(form.validationMessage != nil)
        #expect(try fixture.context.observations.fetchAll().count == 1)
        #expect(throws: (any Error).self) {
            try form.save()
        }
        #expect(try fixture.context.observations.fetchAll().count == 1)
    }

    @Test func aRetryAfterPhotoFailureAttachesOnlyTheMissingPhotos() throws {
        let fixture = try CaptureFixture()
        let form = LogObservationForm(
            context: fixture.context, target: .bed(fixture.bed.id))
        form.notes = "flowering"
        form.photos = [Data([0x01])]
        let first = try form.save()
        form.photos.append(Data([0x02]))
        let second = try form.save()
        #expect(first.id == second.id)
        #expect(try fixture.context.observations.fetchAll().count == 1)
        #expect(try fixture.context.observations.photos(for: first.id).count == 2)
    }

    @Test func theObservedDateDefaultsToNow() throws {
        let fixture = try CaptureFixture()
        let now = Date(timeIntervalSince1970: 1_720_000_000)
        let form = LogObservationForm(
            context: fixture.context, target: .bed(fixture.bed.id), now: now)
        #expect(form.observedAt == now)
    }

    @Test func aStageOnlyObservationSaves() throws {
        let fixture = try CaptureFixture()
        let plantingID = try planting(fixture).id
        let form = LogObservationForm(
            context: fixture.context, target: .planting(plantingID))
        #expect(!form.canSave)
        form.stage = .germinated
        #expect(form.canSave)
        let saved = try form.save()
        let fetched = try fixture.context.observations.fetch(id: saved.id)
        #expect(fetched?.stage == .germinated)
        #expect(fetched?.notes == nil)
        #expect(fetched?.target == .planting(plantingID))
    }

    @Test func aStageSavesAlongsideItsNote() throws {
        let fixture = try CaptureFixture()
        let plantingID = try planting(fixture).id
        let form = LogObservationForm(
            context: fixture.context, target: .planting(plantingID))
        form.stage = .firstFlower
        form.notes = "first truss open on the south side"
        let saved = try form.save()
        let fetched = try fixture.context.observations.fetch(id: saved.id)
        #expect(fetched?.stage == .firstFlower)
        #expect(fetched?.notes == "first truss open on the south side")
    }

    @Test func aNoteOnlyObservationCarriesNoStage() throws {
        let fixture = try CaptureFixture()
        let form = LogObservationForm(
            context: fixture.context, target: .bed(fixture.bed.id))
        form.notes = "slugs after the rain"
        let saved = try form.save()
        #expect(try fixture.context.observations.fetch(id: saved.id)?.stage == nil)
    }
}
