import Domain
import Foundation
import GardenModel
import Persistence
import Testing

struct ScaleTests {
    @Test func aRealisticGardenLoadsCompletelyAndQuickly() throws {
        let fixture = try GardenFixture()
        for gardenIndex in 0..<4 {
            let garden = Garden(name: "Garden \(gardenIndex)")
            try fixture.structures.create(garden, in: fixture.property.id)
            for bedIndex in 0..<10 {
                let bed = Bed(name: "Bed \(gardenIndex).\(bedIndex)", kind: .raised)
                try fixture.structures.create(bed, in: .garden(garden.id))
                for plantingIndex in 0..<10 {
                    try fixture.addPlanting(
                        in: bed.id,
                        status: plantingIndex % 2 == 0 ? .active : .finished,
                        plantedOn: march
                    )
                }
            }
        }

        let start = ContinuousClock.now
        let overview = try GardenOverview.load(from: fixture.database)
        let elapsed = ContinuousClock.now - start

        #expect(overview.gardens.count == 5)
        let bedCount = overview.gardens.reduce(0) { total, group in
            total + group.beds.count + group.areas.reduce(0) { $0 + $1.beds.count }
        }
        #expect(bedCount == 42)
        let plantingCount = overview.gardens.reduce(0) { total, group in
            total + group.beds.reduce(0) { $0 + $1.plantings.count }
        }
        #expect(plantingCount == 200)
        #expect(elapsed < .seconds(1))
    }
}
