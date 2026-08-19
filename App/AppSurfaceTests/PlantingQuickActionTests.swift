import AppKit
import Persistence
import SwiftUI
import XCTest

import struct Domain.Genus
import struct Domain.PlantFamily
import struct Domain.Planting
import struct Domain.Species

@MainActor
final class PlantingQuickActionTests: XCTestCase {
    func testTheEyeAsksCaptureForObservationPrefilledWithThePlanting() {
        let capture = CaptureStore(stores: nil)
        let planting = Planting.ID.generate()
        let actions = PlantingQuickActions(capture: capture, plantingID: planting)
        actions.logObservation()
        XCTAssertEqual(capture.activeSheet, .logObservation(.planting(planting), stage: nil))
    }

    func testTheBasketAsksCaptureForHarvestPrefilledWithThePlanting() {
        let capture = CaptureStore(stores: nil)
        let planting = Planting.ID.generate()
        let actions = PlantingQuickActions(capture: capture, plantingID: planting)
        actions.recordHarvest()
        XCTAssertEqual(capture.activeSheet, .recordHarvest(planting))
    }

    func testAdoptingStoresKeepsTheSameCaptureStoreInstance() {
        let capture = CaptureStore(stores: nil)
        XCTAssertNil(capture.context)
        capture.present(.tasks)
        capture.adopt(stores: nil)
        XCTAssertEqual(capture.activeSheet, .tasks, "adopt must not reset presentation state")
    }

    private struct Seeded {
        let store: GardenStore
        let planting: Planting
    }

    private func seeded() throws -> Seeded {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        let database = try AppDatabase.open(at: directory.appendingPathComponent("croft.sqlite"))
        let store = GardenStore(database: database)
        store.addGarden(named: "Quick Garden")
        let gardenID = try XCTUnwrap(store.overview?.gardens.first?.garden.id)
        store.addBed(named: "Quick Bed", kind: .raised, in: .garden(gardenID))
        let bed = try XCTUnwrap(store.overview?.gardens.first?.beds.first?.bed)
        let family = PlantFamily(name: "Solanaceae")
        let genus = Genus(familyID: family.id, name: "Solanum")
        let species = Species(genusID: genus.id, scientificName: "Solanum lycopersicum")
        try PlantFamilyRepository(database).insert(family)
        try GenusRepository(database).insert(genus)
        try SpeciesRepository(database).insert(species)
        let planting = Planting(identity: .species(species.id), bedID: bed.id, status: .active)
        try PlantingRepository(database).insert(planting)
        store.refresh()
        return Seeded(store: store, planting: planting)
    }

    private func hostedWindow<Content: View>(_ content: Content) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let hosting = NSHostingView(rootView: content)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        return window
    }

    private func settleToolbar(of window: NSWindow, timeout: TimeInterval = 8) -> NSToolbar? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            if let toolbar = window.toolbar, !toolbar.items.isEmpty {
                RunLoop.main.run(until: Date().addingTimeInterval(0.3))
                return toolbar
            }
        }
        return window.toolbar
    }

    func testQuickActionsRealizeInTheToolbarHierarchyWithAnExplicitStore() throws {
        let fixture = try seeded()
        let capture = CaptureStore(stores: nil)
        let shell = AnyView(
            CroftShell(
                gardenStore: fixture.store,
                captureStore: capture,
                initialSection: .garden,
                initialRoute: .planting(fixture.planting.id)
            )
            .environment(\.appStores, nil)
        )
        let window = hostedWindow(shell)
        let toolbar = try XCTUnwrap(settleToolbar(of: window))
        let labels = toolbar.items.map(\.label)
        XCTAssertTrue(labels.contains("Log Observation"), "labels were \(labels)")
        XCTAssertTrue(labels.contains("Record Harvest"), "labels were \(labels)")
        XCTAssertTrue(labels.contains("Record"), "labels were \(labels)")
    }
}
