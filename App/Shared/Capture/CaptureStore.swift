import Capture
import Foundation
import Persistence
import SwiftUI

import struct Domain.Bed
import enum Domain.GardenTaskTarget
import enum Domain.LifecycleStage
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
    case logObservation(ObservationTarget?, stage: LifecycleStage?)
    case recordHarvest(Planting.ID?)
    case tasks
    case addSeedLot

    var id: Self { self }
}

@MainActor
@Observable
final class CaptureStore {
    private(set) var context: CaptureContext?
    var activeSheet: CaptureSheet?
    var visibleTarget: ObservationTarget?
    var onSaved: () -> Void = {}
    private(set) var saveCount = 0

    init(stores: AppStores?) {
        adopt(stores: stores)
    }

    func adopt(stores: AppStores?) {
        guard let stores else {
            context = nil
            return
        }
        let photoBase =
            (try? DatabaseLocation.url().deletingLastPathComponent())
            .map { $0.appendingPathComponent("Photos", isDirectory: true) }
        context = CaptureContext(
            personal: stores.database,
            knowledge: stores.knowledgeDatabase,
            photos: PhotoStore(
                baseURL: photoBase
                    ?? FileManager.default.temporaryDirectory
                    .appendingPathComponent("CroftPhotos", isDirectory: true)
            ),
            defaults: CaptureDefaults(store: AppDefaultsStore.current)
        )
    }

    var visiblePlanting: Planting.ID? {
        if case .planting(let id) = visibleTarget {
            return id
        }
        return nil
    }

    var visibleBed: Bed.ID? {
        if case .bed(let id) = visibleTarget {
            return id
        }
        return nil
    }

    func present(_ sheet: CaptureSheet) {
        activeSheet = sheet
    }

    func recordStage(_ stage: LifecycleStage) {
        guard let context, let plantingID = visiblePlanting else {
            present(.logObservation(visibleTarget, stage: stage))
            return
        }
        do {
            try QuickStageCapture.record(stage, on: plantingID, context: context)
            didSave()
        } catch {
            present(.logObservation(.planting(plantingID), stage: stage))
        }
    }

    func didSave() {
        saveCount += 1
        onSaved()
    }
}
