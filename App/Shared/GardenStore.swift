import Foundation
import GardenModel
import Persistence
import SwiftUI

import struct Domain.Bed
import enum Domain.BedKind
import struct Domain.Garden
import struct Domain.GrowingArea
import struct Domain.Planting
import enum Domain.UnitSystem

@MainActor
@Observable
final class GardenStore {
    let database: AppDatabase?
    private(set) var overview: GardenOverview?
    private(set) var startupError: String?
    var actionError: String?

    init(database: AppDatabase?) {
        self.database = database
        refresh()
    }

    static func live() -> GardenStore {
        do {
            let database = try AppDatabase.open(at: AppDatabase.defaultURL())
            return GardenStore(database: database)
        } catch {
            let store = GardenStore(database: nil)
            store.startupError =
                "Croft couldn't open its garden records. \(error.localizedDescription)"
            return store
        }
    }

    func refresh() {
        guard let database else {
            return
        }
        do {
            overview = try GardenOverview.load(from: database)
        } catch {
            actionError = error.localizedDescription
        }
    }

    func bedDetail(_ id: Bed.ID) -> BedDetail? {
        guard let database else {
            return nil
        }
        return try? BedDetail.load(id, from: database)
    }

    func plantingDetail(_ id: Planting.ID) -> PlantingDetail? {
        guard let database else {
            return nil
        }
        return try? PlantingDetail.load(id, from: database)
    }

    func plantingTimeline(
        _ id: Planting.ID,
        photos: PhotoStore?,
        display: UnitSystem,
        threatNames: Set<String>
    ) -> PlantingTimeline? {
        guard let database, let photos else {
            return nil
        }
        return try? PlantingTimeline.load(
            id,
            from: database,
            photos: photos,
            display: display,
            threatNames: threatNames)
    }

    func addGarden(named name: String) {
        perform { try $0.addGarden(named: name) }
    }

    func addGrowingArea(named name: String, in gardenID: Garden.ID) {
        perform { try $0.addGrowingArea(named: name, in: gardenID) }
    }

    func addBed(named name: String, kind: BedKind, in parent: BedParent) {
        perform { try $0.addBed(named: name, kind: kind, in: parent) }
    }

    func renameGarden(_ id: Garden.ID, to name: String) {
        perform { try $0.renameGarden(id, to: name) }
    }

    func renameGrowingArea(_ id: GrowingArea.ID, to name: String) {
        perform { try $0.renameGrowingArea(id, to: name) }
    }

    func renameBed(_ id: Bed.ID, to name: String) {
        perform { try $0.renameBed(id, to: name) }
    }

    func archiveGarden(_ id: Garden.ID) {
        perform { try $0.archiveGarden(id) }
    }

    func archiveGrowingArea(_ id: GrowingArea.ID) {
        perform { try $0.archiveGrowingArea(id) }
    }

    func archiveBed(_ id: Bed.ID) {
        perform { try $0.archiveBed(id) }
    }

    func moveBed(_ id: Bed.ID, to parent: BedParent) {
        perform { try $0.moveBed(id, to: parent) }
    }

    func moveGrowingArea(_ id: GrowingArea.ID, to gardenID: Garden.ID) {
        perform { try $0.moveGrowingArea(id, to: gardenID) }
    }

    private func perform(_ edit: (GardenEditor) throws -> Void) {
        guard let database else {
            return
        }
        do {
            try edit(GardenEditor(database))
            refresh()
        } catch GardenEditError.blankName {
            actionError = "Give it a name first."
        } catch {
            actionError = error.localizedDescription
        }
    }
}
