import Domain
import Foundation
import GardenModel
import Persistence
import Testing

struct GardenEditorTests {
    @Test func creatingTheFirstGardenCreatesADefaultProperty() throws {
        let database = try AppDatabase.inMemory()
        let editor = GardenEditor(database)
        let garden = try editor.addGarden(named: "Kitchen Garden")

        let structures = GardenStructureRepository(database)
        let properties = try structures.properties()
        #expect(properties.count == 1)
        #expect(try structures.gardens(in: properties[0].id).map(\.id) == [garden.id])
    }

    @Test func aSecondGardenJoinsTheExistingProperty() throws {
        let fixture = try GardenFixture()
        let editor = GardenEditor(fixture.database)
        try editor.addGarden(named: "Orchard")

        #expect(try fixture.structures.properties().count == 1)
        #expect(try fixture.structures.gardens(in: fixture.property.id).count == 2)
    }

    @Test func addsGrowingAreasAndBeds() throws {
        let fixture = try GardenFixture()
        let editor = GardenEditor(fixture.database)
        let area = try editor.addGrowingArea(named: "Greenhouse", in: fixture.garden.id)
        let bed = try editor.addBed(
            named: "Seed Tray Shelf", kind: .container, in: .growingArea(area.id))

        #expect(
            try fixture.structures.growingAreas(in: fixture.garden.id).map(\.name).contains(
                "Greenhouse"))
        #expect(try fixture.structures.beds(in: .growingArea(area.id)).map(\.id) == [bed.id])
    }

    @Test func renamesRejectBlankNames() throws {
        let fixture = try GardenFixture()
        let editor = GardenEditor(fixture.database)
        #expect(throws: GardenEditError.blankName) {
            try editor.renameGarden(fixture.garden.id, to: "   ")
        }
        #expect(throws: GardenEditError.blankName) {
            try editor.addGarden(named: "")
        }
    }

    @Test func renameTrimsWhitespace() throws {
        let fixture = try GardenFixture()
        let editor = GardenEditor(fixture.database)
        try editor.renameBed(fixture.bed.id, to: "  South Bed ")

        let beds = try fixture.structures.beds(in: .garden(fixture.garden.id))
        #expect(beds.map(\.name) == ["South Bed"])
    }

    @Test func archivingABedHidesItFromTheOverview() throws {
        let fixture = try GardenFixture()
        let editor = GardenEditor(fixture.database)
        try editor.archiveBed(fixture.bed.id)

        let overview = try GardenOverview.load(from: fixture.database)
        #expect(overview.gardens.first?.beds.isEmpty == true)
    }

    @Test func movesABedToAnotherParent() throws {
        let fixture = try GardenFixture()
        let editor = GardenEditor(fixture.database)
        try editor.moveBed(fixture.bed.id, to: .growingArea(fixture.growingArea.id))

        #expect(try fixture.structures.beds(in: .garden(fixture.garden.id)).isEmpty)
        #expect(
            try fixture.structures.beds(in: .growingArea(fixture.growingArea.id)).count == 2)
    }
}
