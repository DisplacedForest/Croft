import Capture
import Foundation
import Persistence
import SwiftUI

import struct Domain.Bed
import enum Domain.GardenTaskTarget
import enum Domain.ObservationTarget
import enum Domain.PlantIdentity
import struct Domain.Planting

struct AddPlantingIntent: Hashable {
    var bedID: Bed.ID?
    var identity: PlantIdentity?
    var planned: Bool

    init(bedID: Bed.ID? = nil, identity: PlantIdentity? = nil, planned: Bool = false) {
        self.bedID = bedID
        self.identity = identity
        self.planned = planned
    }
}

enum CaptureSheet: Identifiable, Hashable {
    case addPlanting(AddPlantingIntent)
    case logObservation(ObservationTarget)
    case recordHarvest(Planting.ID)
    case tasks
    case addSeedLot

    var id: Self { self }
}

@MainActor
@Observable
final class CaptureStore {
    let context: CaptureContext?
    var activeSheet: CaptureSheet?
    var onSaved: () -> Void = {}
    private(set) var saveCount = 0

    init(stores: AppStores?) {
        guard let stores else {
            context = nil
            return
        }
        let photoBase =
            (try? AppDatabase.defaultURL().deletingLastPathComponent())
            .map { $0.appendingPathComponent("Photos", isDirectory: true) }
        context = CaptureContext(
            personal: stores.database,
            knowledge: stores.knowledgeDatabase,
            photos: PhotoStore(
                baseURL: photoBase
                    ?? FileManager.default.temporaryDirectory
                    .appendingPathComponent("CroftPhotos", isDirectory: true)
            ),
            defaults: CaptureDefaults()
        )
    }

    func present(_ sheet: CaptureSheet) {
        activeSheet = sheet
    }

    func didSave() {
        saveCount += 1
        onSaved()
    }
}
