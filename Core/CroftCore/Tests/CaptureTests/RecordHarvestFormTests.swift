import Domain
import Foundation
import GRDB
import Graph
import Persistence
import Testing

@testable import Capture

struct RecordHarvestFormTests {
    private func planting(_ fixture: CaptureFixture) throws -> Planting {
        let planting = Planting(
            identity: .cultivar(fixture.cultivar.id), bedID: fixture.bed.id, status: .active)
        try fixture.context.plantings.insert(planting)
        return planting
    }

    private func fruitingPlanting(
        _ fixture: CaptureFixture,
        parts: [HarvestablePart]
    ) throws -> Planting {
        let species = Species(
            genusID: fixture.species.genusID,
            scientificName: "Capsicum annuum \(parts.count)",
            harvestableParts: parts
        )
        try SpeciesRepository(fixture.context.personal).insert(species)
        let planting = Planting(
            identity: .species(species.id), bedID: fixture.bed.id, status: .active)
        try fixture.context.plantings.insert(planting)
        return planting
    }

    @Test func theLastUsedUnitPrefills() throws {
        let fixture = try CaptureFixture()
        fixture.context.defaults.lastHarvestUnit = .unit(.pound)
        let form = RecordHarvestForm(
            context: fixture.context, plantingID: try planting(fixture).id)
        #expect(form.unitChoice == .unit(.pound))
    }

    @Test func theDefaultUnitFollowsThePreferredSystem() throws {
        let fixture = try CaptureFixture()
        fixture.context.defaults.preferredUnitSystem = .metric
        let metricForm = RecordHarvestForm(
            context: fixture.context, plantingID: try planting(fixture).id)
        #expect(metricForm.unitChoice == .unit(.gram))
        fixture.context.defaults.preferredUnitSystem = .imperial
        let imperialForm = RecordHarvestForm(
            context: fixture.context, plantingID: try planting(fixture).id)
        #expect(imperialForm.unitChoice == .unit(.pound))
    }

    @Test func unitChoicesLeadWithThePreferredSystem() throws {
        let fixture = try CaptureFixture()
        fixture.context.defaults.preferredUnitSystem = .imperial
        let form = RecordHarvestForm(
            context: fixture.context, plantingID: try planting(fixture).id)
        #expect(form.unitChoices.first == .unit(.ounce))
        #expect(form.unitChoices.last == .custom)
        #expect(form.unitChoices.contains(.unit(.gram)))
    }

    @Test func partsSeedFromTheSpeciesAndASinglePartPreselects() throws {
        let fixture = try CaptureFixture()
        let single = try fruitingPlanting(fixture, parts: [.fruit])
        let singleForm = RecordHarvestForm(context: fixture.context, plantingID: single.id)
        #expect(singleForm.partChoices == [.fruit])
        #expect(singleForm.harvestedPart == .fruit)
        let several = try fruitingPlanting(fixture, parts: [.leaf, .seed])
        let severalForm = RecordHarvestForm(context: fixture.context, plantingID: several.id)
        #expect(severalForm.partChoices == [.leaf, .seed])
        #expect(severalForm.harvestedPart == nil)
    }

    @Test func aSpeciesWithoutPartsOffersNoPicker() throws {
        let fixture = try CaptureFixture()
        let form = RecordHarvestForm(
            context: fixture.context, plantingID: try planting(fixture).id)
        #expect(form.partChoices.isEmpty)
        #expect(form.harvestedPart == nil)
    }

    @Test func zeroAndMalformedQuantitiesAreRejected() throws {
        let fixture = try CaptureFixture()
        let form = RecordHarvestForm(
            context: fixture.context, plantingID: try planting(fixture).id)
        form.quantityText = "0"
        #expect(!form.canSave)
        form.quantityText = "a handful"
        #expect(!form.canSave)
        #expect(throws: CaptureValidationError.incomplete) {
            try form.save()
        }
        #expect(try fixture.context.harvests.fetchAll().isEmpty)
    }

    @Test func aFractionalCountIsRejected() throws {
        let fixture = try CaptureFixture()
        let form = RecordHarvestForm(
            context: fixture.context, plantingID: try planting(fixture).id)
        form.unitChoice = .unit(.count)
        form.quantityText = "2,5"
        #expect(!form.canSave)
        form.quantityText = "2"
        #expect(form.canSave)
    }

    @Test func aCustomUnitRequiresItsLabel() throws {
        let fixture = try CaptureFixture()
        let form = RecordHarvestForm(
            context: fixture.context, plantingID: try planting(fixture).id)
        form.quantityText = "3"
        form.unitChoice = .custom
        #expect(!form.canSave)
        form.customUnit = "baskets"
        #expect(form.canSave)
    }

    @Test func savingStoresTheEnteredUnitInBothSystems() throws {
        let fixture = try CaptureFixture()
        let plantingID = try planting(fixture).id
        let metricForm = RecordHarvestForm(context: fixture.context, plantingID: plantingID)
        metricForm.quantityText = "1,5"
        metricForm.unitChoice = .unit(.kilogram)
        metricForm.quality = .excellent
        let metric = try metricForm.save()
        #expect(try metric.yield == measuredYield(1.5, .kilogram))
        let imperialForm = RecordHarvestForm(context: fixture.context, plantingID: plantingID)
        imperialForm.quantityText = "2.5"
        imperialForm.unitChoice = .unit(.pound)
        let imperial = try imperialForm.save()
        #expect(try imperial.yield == measuredYield(2.5, .pound))
        #expect(fixture.context.defaults.lastHarvestUnit == .unit(.pound))
        #expect(try fixture.context.harvests.harvests(forPlanting: plantingID).count == 2)
    }

    @Test func savingRecordsThePart() throws {
        let fixture = try CaptureFixture()
        let planting = try fruitingPlanting(fixture, parts: [.fruit])
        let form = RecordHarvestForm(context: fixture.context, plantingID: planting.id)
        form.quantityText = "4"
        form.unitChoice = .unit(.count)
        let harvest = try form.save()
        #expect(harvest.harvestedPart == .fruit)
        #expect(
            try fixture.context.harvests.fetch(id: harvest.id)?.harvestedPart == .fruit)
    }

    @Test func logAnotherKeepsPlantingUnitAndPartAndClearsTheRest() throws {
        let fixture = try CaptureFixture()
        let planting = try fruitingPlanting(fixture, parts: [.fruit])
        let form = RecordHarvestForm(context: fixture.context, plantingID: planting.id)
        form.quantityText = "2"
        form.unitChoice = .unit(.count)
        form.quality = .good
        _ = try form.save()
        form.prepareForAnother()
        #expect(form.quantityText.isEmpty)
        #expect(form.quality == nil)
        #expect(form.unitChoice == .unit(.count))
        #expect(form.harvestedPart == .fruit)
        #expect(form.savedCount == 1)
        #expect(!form.canSave)
    }
}

func measuredYield(_ amount: Double, _ unit: QuantityUnit) throws -> HarvestYield {
    .measured(try Quantity(amount: amount, unit: unit))
}
