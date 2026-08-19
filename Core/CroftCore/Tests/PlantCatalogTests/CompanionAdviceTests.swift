import Domain
import Foundation
import Graph
import Persistence
import PlantCatalog
import Testing

private struct CompanionFixture {
    let fixture: CatalogFixture
    let advice: CompanionAdvice
    let fennel: Species

    init() throws {
        fixture = try CatalogFixture()
        fennel = Species(
            genusID: ocimum.id,
            scientificName: "Foeniculum vulgare",
            commonNames: ["Fennel"]
        )
        try fixture.species.insert(fennel)
        advice = CompanionAdvice(fixture.database)
    }

    func plantActive(_ identity: PlantIdentity, in bed: Bed.ID) throws {
        try fixture.plantings.insert(
            Planting(
                identity: identity,
                bedID: bed,
                plantedOn: Date(timeIntervalSince1970: 1_715_000_000),
                status: .active
            ))
    }

    func relate(
        _ origin: Species.ID,
        _ type: RelationshipType,
        _ target: Species.ID,
        source: String = "companion planting trials"
    ) throws {
        try fixture.database.writer.write { db in
            _ = try GraphStore.relate(
                from: EntityRef(id: origin.rawValue, type: .plant),
                type,
                to: EntityRef(id: target.rawValue, type: .plant),
                provenance: Provenance(source: source, sourceType: .reference),
                in: db
            )
        }
    }
}

struct CompanionAdviceTests {
    @Test func aSourcedCompanionShowsAQuietNote() throws {
        let companion = try CompanionFixture()
        try companion.plantActive(.species(basil.id), in: longBed.id)
        try companion.relate(tomato.id, .companionWith, basil.id)

        let notes = try companion.advice.notes(for: .species(tomato.id), inBed: longBed.id)
        #expect(
            notes == [
                CompanionNote(
                    plantName: "Basil", source: "companion planting trials",
                    isAntagonist: false)
            ])
    }

    @Test func aSourcedAntagonistShowsTheAdvisory() throws {
        let companion = try CompanionFixture()
        try companion.plantActive(.species(companion.fennel.id), in: longBed.id)
        try companion.relate(
            companion.fennel.id, .antagonisticTo, tomato.id, source: "field guide")

        let notes = try companion.advice.notes(for: .species(tomato.id), inBed: longBed.id)
        #expect(
            notes == [
                CompanionNote(plantName: "Fennel", source: "field guide", isAntagonist: true)
            ])
    }

    @Test func bothPresentPutsTheAntagonistFirst() throws {
        let companion = try CompanionFixture()
        try companion.plantActive(.species(basil.id), in: longBed.id)
        try companion.plantActive(.species(companion.fennel.id), in: longBed.id)
        try companion.relate(tomato.id, .companionWith, basil.id)
        try companion.relate(companion.fennel.id, .antagonisticTo, tomato.id)

        let notes = try companion.advice.notes(for: .species(tomato.id), inBed: longBed.id)
        #expect(notes.count == 2)
        #expect(notes[0].isAntagonist)
        #expect(notes[0].plantName == "Fennel")
        #expect(!notes[1].isAntagonist)
        #expect(notes[1].plantName == "Basil")
    }

    @Test func anEmptyBedOrUnrelatedNeighborsStaySilent() throws {
        let companion = try CompanionFixture()
        let empty = try companion.advice.notes(for: .species(tomato.id), inBed: longBed.id)
        #expect(empty.isEmpty)

        try companion.plantActive(.species(basil.id), in: longBed.id)
        let unrelated = try companion.advice.notes(for: .species(tomato.id), inBed: longBed.id)
        #expect(unrelated.isEmpty)
    }

    @Test func aCultivarCandidateResolvesToItsSpecies() throws {
        let companion = try CompanionFixture()
        try companion.plantActive(.species(basil.id), in: longBed.id)
        try companion.relate(tomato.id, .companionWith, basil.id)

        let notes = try companion.advice.notes(
            for: .cultivar(brandywine.id), inBed: longBed.id)
        #expect(notes.count == 1)
        #expect(notes[0].plantName == "Basil")
    }

    @Test func finishedPlantingsAndOtherBedsDoNotCount() throws {
        let companion = try CompanionFixture()
        try companion.fixture.plantings.insert(
            Planting(
                identity: .species(basil.id),
                bedID: longBed.id,
                plantedOn: Date(timeIntervalSince1970: 1_700_000_000),
                status: .finished,
                endedOn: Date(timeIntervalSince1970: 1_710_000_000)
            ))
        try companion.plantActive(.species(companion.fennel.id), in: tunnelBed.id)
        try companion.relate(tomato.id, .companionWith, basil.id)
        try companion.relate(companion.fennel.id, .antagonisticTo, tomato.id)

        let notes = try companion.advice.notes(for: .species(tomato.id), inBed: longBed.id)
        #expect(notes.isEmpty)
    }

    @Test func edgeDirectionDoesNotMatter() throws {
        let companion = try CompanionFixture()
        try companion.plantActive(.species(basil.id), in: longBed.id)
        try companion.relate(basil.id, .companionWith, tomato.id)

        let notes = try companion.advice.notes(for: .species(tomato.id), inBed: longBed.id)
        #expect(notes.count == 1)
        #expect(notes[0].plantName == "Basil")
    }
}
