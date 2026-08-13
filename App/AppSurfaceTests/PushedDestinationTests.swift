import AppKit
import Persistence
import SwiftUI
import XCTest

import enum Domain.BedKind

@MainActor
final class PushedDestinationTests: XCTestCase {
    func testPushedBedDetailRendersWithProductionInjections() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = try AppDatabase.open(at: directory.appendingPathComponent("croft.sqlite"))
        let gardenStore = GardenStore(database: database)
        gardenStore.addGarden(named: "Surface Test Garden")
        let gardenID = try XCTUnwrap(gardenStore.overview?.gardens.first?.garden.id)
        gardenStore.addBed(named: "Surface Test Bed", kind: .raised, in: .garden(gardenID))
        let bed = try XCTUnwrap(gardenStore.overview?.gardens.first?.beds.first?.bed)

        let shell = AnyView(
            CroftShell(
                gardenStore: gardenStore,
                initialSection: .garden,
                initialRoute: .bed(bed.id)
            )
            .environment(\.appStores, nil)
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let hosting = NSHostingView(rootView: shell)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(2))

        XCTAssertNotNil(hosting.window)
    }
}
