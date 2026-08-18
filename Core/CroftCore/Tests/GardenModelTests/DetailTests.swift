import Domain
import Foundation
import GardenModel
import Persistence
import Testing

struct BedDetailTests {
    @Test func splitsCurrentAndPastPlantings() throws {
        let fixture = try GardenFixture()
        let active = try fixture.addPlanting(status: .active, plantedOn: april)
        let planned = try fixture.addPlanting(status: .planned)
        let finished = try fixture.addPlanting(status: .finished, plantedOn: march, endedOn: may)
        let failed = try fixture.addPlanting(status: .failed, plantedOn: march, endedOn: june)

        let detail = try #require(try BedDetail.load(fixture.bed.id, from: fixture.database))
        #expect(detail.bed == fixture.bed)
        #expect(detail.current.map(\.planting.id) == [active.id, planned.id])
        #expect(detail.past.map(\.planting.id) == [failed.id, finished.id])
    }

    @Test func namesTheBedsLocation() throws {
        let fixture = try GardenFixture()
        let inGarden = try #require(try BedDetail.load(fixture.bed.id, from: fixture.database))
        #expect(inGarden.locationName == "Kitchen Garden")

        let inArea = try #require(try BedDetail.load(fixture.tunnelBed.id, from: fixture.database))
        #expect(inArea.locationName == "Polytunnel, Kitchen Garden")
    }

    @Test func aMissingBedLoadsAsNil() throws {
        let fixture = try GardenFixture()
        #expect(try BedDetail.load(Bed.ID.generate(), from: fixture.database) == nil)
    }
}

struct PlantingDetailTests {
    @Test func carriesIdentityAndLocation() throws {
        let fixture = try GardenFixture()
        let planting = try fixture.addPlanting(
            status: .active, plantedOn: march, transplantedOn: april)

        let detail = try #require(
            try PlantingDetail.load(planting.id, from: fixture.database))
        #expect(detail.plantName == "Brandywine")
        #expect(detail.botanicalName == "Solanum lycopersicum")
        #expect(detail.bedName == "Long Bed")
    }

    @Test func aSpeciesIdentityShowsTheCommonName() throws {
        let fixture = try GardenFixture()
        let planting = try fixture.addPlanting(identity: .species(fixture.tomatoSpecies.id))

        let detail = try #require(
            try PlantingDetail.load(planting.id, from: fixture.database))
        #expect(detail.plantName == "Tomato")
        #expect(detail.botanicalName == "Solanum lycopersicum")
    }

    @Test func describesSeedLotLineage() throws {
        let fixture = try GardenFixture()
        let lots = SeedLotRepository(fixture.database)
        let lot = SeedLot(cultivarID: fixture.tomatoCultivar.id, source: "Baker Creek")
        try lots.insert(lot)
        let planting = Planting(
            identity: .cultivar(fixture.tomatoCultivar.id),
            bedID: fixture.bed.id,
            source: .seedLot(lot.id)
        )
        try fixture.plantings.insert(planting)

        let detail = try #require(
            try PlantingDetail.load(planting.id, from: fixture.database))
        #expect(detail.lineage == "Sown from seed, Baker Creek")
    }

}
