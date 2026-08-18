import Domain
import Foundation
import Persistence
import Testing

@testable import Capture

private func seededCultivarPlanting(_ fixture: CaptureFixture) throws -> Planting {
    let planting = Planting(
        identity: .cultivar(fixture.cultivar.id), bedID: fixture.bed.id, status: .active)
    try fixture.context.plantings.insert(planting)
    return planting
}

private func seededSpeciesPlanting(
    _ fixture: CaptureFixture,
    parts: [HarvestablePart],
    name: String
) throws -> Planting {
    let species = Species(
        genusID: fixture.species.genusID,
        scientificName: name,
        harvestableParts: parts
    )
    try SpeciesRepository(fixture.context.personal).insert(species)
    let planting = Planting(
        identity: .species(species.id), bedID: fixture.bed.id, status: .active)
    try fixture.context.plantings.insert(planting)
    return planting
}

struct CaptureTargetChoiceTests {
    @Test func choicesListPlantingsBedsAndGardens() throws {
        let fixture = try CaptureFixture()
        let planting = try seededCultivarPlanting(fixture)
        let choices = try fixture.context.targetChoices()
        #expect(choices.plantings.map(\.target) == [.planting(planting.id)])
        #expect(choices.plantings.first?.label == "Brandywine · Long Bed")
        #expect(
            choices.beds.map(\.label) == [
                "Long Bed · Kitchen Garden", "Tunnel Bed · Kitchen Garden",
            ])
        #expect(choices.gardens.map(\.label) == ["Kitchen Garden"])
    }

    @Test func anEmptyDatabaseYieldsEmptyChoices() throws {
        let fixture = try CaptureFixture()
        let choices = try fixture.context.targetChoices()
        #expect(choices.plantings.isEmpty)
        #expect(!choices.isEmpty)
    }

    @Test func targetLabelResolvesAPlantIdentity() throws {
        let fixture = try CaptureFixture()
        #expect(
            try fixture.context.targetLabel(for: .plant(.cultivar(fixture.cultivar.id)))
                == "Brandywine")
    }

    @Test func targetLabelResolvesAListedBed() throws {
        let fixture = try CaptureFixture()
        #expect(
            try fixture.context.targetLabel(for: .bed(fixture.bed.id))
                == "Long Bed · Kitchen Garden")
    }
}

struct QuickStageCaptureTests {
    @Test func recordsAStageOnlyObservationAgainstThePlanting() throws {
        let fixture = try CaptureFixture()
        let planting = try seededCultivarPlanting(fixture)
        let saved = try QuickStageCapture.record(
            .firstFlower, on: planting.id, context: fixture.context)
        let fetched = try fixture.context.observations.fetch(id: saved.id)
        #expect(fetched?.stage == .firstFlower)
        #expect(fetched?.target == .planting(planting.id))
        #expect(fetched?.notes == nil)
        #expect(fetched?.photos.isEmpty == true)
    }
}

struct CaptureTargetFormTests {
    @Test func anObservationWithoutATargetCannotSave() throws {
        let fixture = try CaptureFixture()
        let form = LogObservationForm(context: fixture.context, target: nil)
        form.notes = "volunteer squash by the fence"
        #expect(!form.canSave)
        #expect(throws: CaptureValidationError.incomplete) {
            try form.save()
        }
        form.target = .bed(fixture.bed.id)
        #expect(form.canSave)
        let saved = try form.save()
        #expect(saved.target == .bed(fixture.bed.id))
    }

    @Test func aHarvestWithoutAPlantingCannotSave() throws {
        let fixture = try CaptureFixture()
        let form = RecordHarvestForm(context: fixture.context, plantingID: nil)
        form.quantityText = "2"
        #expect(!form.canSave)
        #expect(throws: CaptureValidationError.incomplete) {
            try form.save()
        }
    }

    @Test func harvestPartChoicesReseedWhenThePlantingChanges() throws {
        let fixture = try CaptureFixture()
        let fruiting = try seededSpeciesPlanting(
            fixture, parts: [.fruit], name: "Capsicum annuum")
        let leafy = try seededSpeciesPlanting(
            fixture, parts: [.leaf, .stem], name: "Ocimum basilicum")
        let form = RecordHarvestForm(context: fixture.context, plantingID: nil)
        #expect(form.partChoices.isEmpty)
        form.plantingID = fruiting.id
        #expect(form.partChoices == [.fruit])
        #expect(form.harvestedPart == .fruit)
        form.plantingID = leafy.id
        #expect(form.partChoices == [.leaf, .stem])
        #expect(form.harvestedPart == nil)
    }
}
