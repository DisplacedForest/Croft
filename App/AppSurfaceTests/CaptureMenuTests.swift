import AppKit
import SwiftUI
import XCTest

import struct Domain.Bed
import enum Domain.BedKind
import enum Domain.LifecycleStage
import enum Domain.ObservationTarget
import enum Domain.PlantIdentity
import struct Domain.Planting
import struct Domain.Species

@MainActor
final class CaptureMenuTests: XCTestCase {
    func testRoutesResolveToCaptureTargets() {
        let plantingID = Planting.ID(rawValue: "pl1")
        let bedID = Bed.ID(rawValue: "bed1")
        let identity = PlantIdentity.species(Species.ID(rawValue: "species:s"))
        XCTAssertEqual(
            CaptureTargetResolver.target(for: .planting(plantingID)), .planting(plantingID))
        XCTAssertEqual(CaptureTargetResolver.target(for: .bed(bedID)), .bed(bedID))
        XCTAssertEqual(CaptureTargetResolver.target(for: .plant(identity)), .plant(identity))
        XCTAssertNil(CaptureTargetResolver.target(for: nil))
    }

    func testStoreExposesTheVisiblePlantingAndBed() {
        let store = CaptureStore(stores: nil)
        XCTAssertNil(store.visiblePlanting)
        XCTAssertNil(store.visibleBed)
        let plantingID = Planting.ID(rawValue: "pl1")
        store.visibleTarget = .planting(plantingID)
        XCTAssertEqual(store.visiblePlanting, plantingID)
        XCTAssertNil(store.visibleBed)
        let bedID = Bed.ID(rawValue: "bed1")
        store.visibleTarget = .bed(bedID)
        XCTAssertEqual(store.visibleBed, bedID)
        XCTAssertNil(store.visiblePlanting)
    }

    func testQuickStageFallsBackToTheObservationSheet() {
        let store = CaptureStore(stores: nil)
        store.visibleTarget = .bed(Bed.ID(rawValue: "bed1"))
        store.recordStage(.germinated)
        XCTAssertEqual(
            store.activeSheet,
            .logObservation(.bed(Bed.ID(rawValue: "bed1")), stage: .germinated))
    }

    func testMenuRendersForEveryVisibleContext() {
        let targets: [ObservationTarget?] = [
            nil,
            .planting(Planting.ID(rawValue: "pl1")),
            .bed(Bed.ID(rawValue: "bed1")),
            .plant(.species(Species.ID(rawValue: "species:s"))),
        ]
        for target in targets {
            let store = CaptureStore(stores: nil)
            store.visibleTarget = target
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 80),
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )
            let hosting = NSHostingView(rootView: CaptureMenu(capture: store).padding())
            window.contentView = hosting
            hosting.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            XCTAssertNotNil(hosting.window)
        }
    }
}
