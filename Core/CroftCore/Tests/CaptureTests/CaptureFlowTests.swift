import Domain
import Foundation
import GRDB
import Graph
import Persistence
import PlantCatalog
import Testing

@testable import Capture

struct AddPlantingFormTests {
    @Test func defaultsPrefillCurrentDateAndLastUsedBed() throws {
        let fixture = try CaptureFixture()
        fixture.context.defaults.lastBedID = fixture.secondBed.id
        let now = Date(timeIntervalSince1970: 1_720_000_000)
        let form = AddPlantingForm(context: fixture.context, now: now)
        #expect(form.plantedOn == now)
        #expect(form.bedID == fixture.secondBed.id)
    }

    @Test func anExplicitBedBeatsTheRemembered() throws {
        let fixture = try CaptureFixture()
        fixture.context.defaults.lastBedID = fixture.secondBed.id
        let form = AddPlantingForm(context: fixture.context, bedID: fixture.bed.id)
        #expect(form.bedID == fixture.bed.id)
    }

    @Test func savingWithoutAPlantIsRejectedAndWritesNothing() throws {
        let fixture = try CaptureFixture()
        let form = AddPlantingForm(context: fixture.context, bedID: fixture.bed.id)
        #expect(!form.canSave)
        #expect(throws: CaptureValidationError.incomplete) {
            try form.save()
        }
        #expect(form.validationMessage != nil)
        #expect(try fixture.context.plantings.fetchAll().isEmpty)
    }

    @Test func savingCreatesAPlantingWithItsGraphEdges() throws {
        let fixture = try CaptureFixture()
        let lot = SeedLot(cultivarID: fixture.cultivar.id)
        try fixture.context.seedLots.insert(lot)
        let form = AddPlantingForm(context: fixture.context, bedID: fixture.bed.id)
        form.identity = .cultivar(fixture.cultivar.id)
        form.source = .seedLot(lot.id)
        form.quantity = 4
        let planting = try form.save()
        let edges = try fixture.context.personal.writer.read { db in
            (
                identity: try GraphStore.outgoing(
                    from: planting.id.rawValue, via: .instanceOf, in: db
                ).map(\.target.id),
                location: try GraphStore.outgoing(
                    from: planting.id.rawValue, via: .locatedIn, in: db
                ).map(\.target.id),
                lineage: try GraphStore.outgoing(
                    from: planting.id.rawValue, via: .plantedFrom, in: db
                ).map(\.target.id)
            )
        }
        #expect(edges.identity == [fixture.cultivar.id.rawValue])
        #expect(edges.location == [fixture.bed.id.rawValue])
        #expect(edges.lineage == [lot.id.rawValue])
        #expect(fixture.context.defaults.lastBedID == fixture.bed.id)
        #expect(planting.status == .active)
    }

    @Test func rotationStateTracksBedAndIdentitySelection() throws {
        let fixture = try CaptureFixture()
        let calendar = PlantingWindows.utcCalendar
        var planted = DateComponents()
        planted.year = 2025
        planted.month = 5
        planted.day = 15
        var ended = planted
        ended.month = 9
        var referenceParts = planted
        referenceParts.year = 2026
        let reference = calendar.date(from: referenceParts)!
        try fixture.context.plantings.insert(
            Planting(
                identity: .species(fixture.species.id),
                bedID: fixture.bed.id,
                plantedOn: calendar.date(from: planted)!,
                status: .finished,
                endedOn: calendar.date(from: ended)!
            ))

        let form = AddPlantingForm(context: fixture.context, bedID: fixture.bed.id, planned: true)
        form.refreshRotation(on: reference)
        #expect(form.rotationWarning == nil)
        #expect(form.bedHistory.map(\.familyName) == ["Solanaceae"])
        #expect(!form.showsEmptyHistoryNote)

        form.identity = .cultivar(fixture.cultivar.id)
        form.refreshRotation(on: reference)
        #expect(form.rotationWarning == RotationWarning(familyName: "Solanaceae", year: 2025))

        form.bedID = fixture.secondBed.id
        form.refreshRotation(on: reference)
        #expect(form.rotationWarning == nil)
        #expect(form.bedHistory.isEmpty)
        #expect(form.showsEmptyHistoryNote)
    }

    @Test func activeModeSkipsHistoryAndEmptyNote() throws {
        let fixture = try CaptureFixture()
        let form = AddPlantingForm(context: fixture.context, bedID: fixture.bed.id)
        form.refreshRotation()
        #expect(form.bedHistory.isEmpty)
        #expect(!form.showsEmptyHistoryNote)
    }

    @Test func companionNotesTrackBedAndIdentitySelection() throws {
        let fixture = try CaptureFixture()
        let neighbor = Species(
            genusID: fixture.species.genusID,
            scientificName: "Ocimum basilicum",
            commonNames: ["Basil"]
        )
        try SpeciesRepository(fixture.context.personal).insert(neighbor)
        try fixture.context.plantings.insert(
            Planting(
                identity: .species(neighbor.id),
                bedID: fixture.bed.id,
                plantedOn: Date(timeIntervalSince1970: 1_715_000_000),
                status: .active
            ))
        try fixture.context.personal.writer.write { db in
            _ = try GraphStore.relate(
                from: EntityRef(id: fixture.species.id.rawValue, type: .plant),
                .companionWith,
                to: EntityRef(id: neighbor.id.rawValue, type: .plant),
                provenance: Provenance(source: "trials", sourceType: .reference),
                in: db
            )
        }

        let form = AddPlantingForm(
            context: fixture.context,
            bedID: fixture.bed.id,
            identity: .species(fixture.species.id)
        )
        form.refreshRotation()
        #expect(
            form.companionNotes == [
                CompanionNote(plantName: "Basil", source: "trials", isAntagonist: false)
            ])

        form.bedID = fixture.secondBed.id
        form.refreshRotation()
        #expect(form.companionNotes.isEmpty)
    }

    @Test func aPreselectedIdentityArrivesReadyToSave() throws {
        let fixture = try CaptureFixture()
        let form = AddPlantingForm(
            context: fixture.context,
            bedID: fixture.bed.id,
            identity: .cultivar(fixture.cultivar.id)
        )
        #expect(form.identity == .cultivar(fixture.cultivar.id))
        #expect(form.canSave)
    }

    @Test func plannedModeSavesWithoutAPlantedDate() throws {
        let fixture = try CaptureFixture()
        let form = AddPlantingForm(
            context: fixture.context,
            bedID: fixture.bed.id,
            identity: .cultivar(fixture.cultivar.id),
            planned: true
        )
        let planting = try form.save()
        #expect(planting.status == .planned)
        #expect(planting.plantedOn == nil)
        let stored = try #require(try fixture.context.plantings.fetch(id: planting.id))
        #expect(stored.status == .planned)
        #expect(stored.plantedOn == nil)
        let located = try fixture.context.personal.writer.read { db in
            try GraphStore.outgoing(from: planting.id.rawValue, via: .locatedIn, in: db)
                .map(\.target.id)
        }
        #expect(located == [fixture.bed.id.rawValue])
    }

    @Test func aKnowledgeCultivarIsAdoptedIntoThePersonalDatabase() throws {
        let (knowledge, knowledgeCultivar) = try CaptureFixture.knowledgeDatabase()
        let fixture = try CaptureFixture(knowledge: knowledge)
        let form = AddPlantingForm(context: fixture.context, bedID: fixture.bed.id)
        form.identity = .cultivar(knowledgeCultivar.id)
        let planting = try form.save()
        let personal = fixture.context.personal
        #expect(try CultivarRepository(personal).fetch(id: knowledgeCultivar.id) != nil)
        #expect(
            try SpeciesRepository(personal).fetch(id: knowledgeCultivar.speciesID) != nil)
        #expect(planting.identity == .cultivar(knowledgeCultivar.id))
    }

    @Test func anUnknownIdentityFailsWithoutHalfWrites() throws {
        let (knowledge, _) = try CaptureFixture.knowledgeDatabase()
        let fixture = try CaptureFixture(knowledge: knowledge)
        let personal = fixture.context.personal
        let familiesBefore = try PlantFamilyRepository(personal).fetchAll().count
        let generaBefore = try GenusRepository(personal).fetchAll().count
        let speciesBefore = try SpeciesRepository(personal).fetchAll().count
        let cultivarsBefore = try CultivarRepository(personal).fetchAll().count
        let form = AddPlantingForm(context: fixture.context, bedID: fixture.bed.id)
        form.identity = .cultivar(Cultivar.ID(rawValue: "cultivar:missing/ghost"))
        #expect(throws: PlantAdoptionError.self) {
            try form.save()
        }
        #expect(try fixture.context.plantings.fetchAll().isEmpty)
        #expect(try PlantFamilyRepository(personal).fetchAll().count == familiesBefore)
        #expect(try GenusRepository(personal).fetchAll().count == generaBefore)
        #expect(try SpeciesRepository(personal).fetchAll().count == speciesBefore)
        #expect(try CultivarRepository(personal).fetchAll().count == cultivarsBefore)
    }

    @Test func aFailedPlantingInsertRollsBackTheAdoptedChain() throws {
        let (knowledge, knowledgeCultivar) = try CaptureFixture.knowledgeDatabase()
        let fixture = try CaptureFixture(knowledge: knowledge)
        let personal = fixture.context.personal
        let form = AddPlantingForm(
            context: fixture.context, bedID: Bed.ID(rawValue: "bed:missing"))
        form.identity = .cultivar(knowledgeCultivar.id)
        #expect(throws: (any Error).self) {
            try form.save()
        }
        #expect(form.validationMessage != nil)
        #expect(try fixture.context.plantings.fetchAll().isEmpty)
        #expect(try CultivarRepository(personal).fetch(id: knowledgeCultivar.id) == nil)
        #expect(
            try SpeciesRepository(personal).fetch(id: knowledgeCultivar.speciesID) == nil)
        #expect(
            try GenusRepository(personal).fetch(id: Genus.ID(rawValue: "genus:lactuca")) == nil)
        #expect(
            try PlantFamilyRepository(personal)
                .fetch(id: PlantFamily.ID(rawValue: "family:asteraceae")) == nil)

        form.bedID = fixture.bed.id
        let planting = try form.save()
        #expect(try fixture.context.plantings.fetch(id: planting.id) != nil)
        #expect(try CultivarRepository(personal).fetch(id: knowledgeCultivar.id) != nil)
    }

    @Test func adoptionNeverDeletesPreexistingPersonalRows() throws {
        let (knowledge, knowledgeCultivar) = try CaptureFixture.knowledgeDatabase()
        let fixture = try CaptureFixture(knowledge: knowledge)
        let personal = fixture.context.personal
        _ = try fixture.context.adopter.adopt(.species(knowledgeCultivar.speciesID))
        let form = AddPlantingForm(
            context: fixture.context, bedID: Bed.ID(rawValue: "bed:missing"))
        form.identity = .cultivar(knowledgeCultivar.id)
        #expect(throws: (any Error).self) {
            try form.save()
        }
        #expect(try CultivarRepository(personal).fetch(id: knowledgeCultivar.id) == nil)
        #expect(
            try SpeciesRepository(personal).fetch(id: knowledgeCultivar.speciesID) != nil)
    }

    @Test func abandoningAFormWritesNothing() throws {
        let fixture = try CaptureFixture()
        let form = AddPlantingForm(context: fixture.context, bedID: fixture.bed.id)
        form.identity = .cultivar(fixture.cultivar.id)
        form.quantity = 12
        #expect(try fixture.context.plantings.fetchAll().isEmpty)
    }
}

struct TaskFlowTests {
    @Test func aBlankTitleIsRejected() throws {
        let fixture = try CaptureFixture()
        let form = AddTaskForm(context: fixture.context)
        form.title = "   "
        #expect(!form.canSave)
        #expect(throws: CaptureValidationError.incomplete) {
            try form.save()
        }
        #expect(try fixture.context.tasks.fetchAll().isEmpty)
    }

    @Test func aTaskSavesWithItsTarget() throws {
        let fixture = try CaptureFixture()
        let form = AddTaskForm(context: fixture.context, target: .bed(fixture.bed.id))
        form.title = "Water the long bed"
        form.type = .water
        let task = try form.save()
        #expect(try fixture.context.tasks.tasks(for: .bed(fixture.bed.id)).map(\.id) == [task.id])
        #expect(task.completed == false)
    }

    @Test func theChecklistCompletesATask() throws {
        let fixture = try CaptureFixture()
        let form = AddTaskForm(context: fixture.context)
        form.title = "Thin the carrots"
        form.type = .thin
        let task = try form.save()
        let checklist = TaskChecklist(context: fixture.context)
        #expect(checklist.open.map(\.id) == [task.id])
        let completedOn = Date(timeIntervalSince1970: 1_720_000_000)
        checklist.complete(task.id, on: completedOn)
        #expect(checklist.open.isEmpty)
        let stored = try fixture.context.tasks.fetch(id: task.id)
        #expect(stored?.completed == true)
        #expect(stored?.completedOn == completedOn)
    }
}

struct AddSeedLotFormTests {
    @Test func aMissingCultivarIsRejected() throws {
        let fixture = try CaptureFixture()
        let form = AddSeedLotForm(context: fixture.context)
        #expect(!form.canSave)
        #expect(throws: CaptureValidationError.incomplete) {
            try form.save()
        }
        #expect(try fixture.context.seedLots.fetchAll().isEmpty)
    }

    @Test func aSeedLotSavesWithItsLineageEdge() throws {
        let fixture = try CaptureFixture()
        let form = AddSeedLotForm(context: fixture.context)
        form.cultivarID = fixture.cultivar.id
        form.source = "Baker Creek"
        form.seedCountText = "40"
        let lot = try form.save()
        let targets = try fixture.context.personal.writer.read { db in
            try GraphStore.outgoing(from: lot.id.rawValue, via: .lotOf, in: db)
                .map(\.target.id)
        }
        #expect(targets == [fixture.cultivar.id.rawValue])
        #expect(lot.seedCount == 40)
    }

    @Test func aKnowledgeCultivarIsAdoptedBeforeTheLotSaves() throws {
        let (knowledge, knowledgeCultivar) = try CaptureFixture.knowledgeDatabase()
        let fixture = try CaptureFixture(knowledge: knowledge)
        let form = AddSeedLotForm(context: fixture.context)
        form.cultivarID = knowledgeCultivar.id
        _ = try form.save()
        #expect(
            try CultivarRepository(fixture.context.personal)
                .fetch(id: knowledgeCultivar.id) != nil)
    }

    @Test func aGarbageSeedCountBlocksSaving() throws {
        let fixture = try CaptureFixture()
        let form = AddSeedLotForm(context: fixture.context)
        form.cultivarID = fixture.cultivar.id
        form.seedCountText = "plenty"
        #expect(!form.canSave)
    }
}
