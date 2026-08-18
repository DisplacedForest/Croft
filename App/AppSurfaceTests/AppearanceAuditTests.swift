import AppKit
import Capture
import Persistence
import PlantCatalog
import SwiftUI
import XCTest

import struct Domain.Bed
import enum Domain.BedKind
import enum Domain.GardenTaskType
import enum Domain.ObservationTarget
import enum Domain.PlantIdentity
import struct Domain.Planting

@MainActor
final class AppearanceAuditTests: XCTestCase {
    private struct Scenery {
        let directory: URL
        let stores: AppStores
        let gardenStore: GardenStore
        let context: CaptureContext
        let bedID: Bed.ID
        let plantingID: Planting.ID?
        let plantIdentity: PlantIdentity?
    }

    private nonisolated(unsafe) var cleanupDirectories: [URL] = []

    override func tearDown() {
        for directory in cleanupDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        cleanupDirectories = []
        super.tearDown()
    }

    private struct Screen {
        let name: String
        let size: NSSize
        let view: AnyView
    }

    func testEveryScreenRendersDetailContentOnTokenSurfacesInBothAppearances() throws {
        let scenery = try makeScenery()
        let empty = try makeScenery(seeded: false)

        for screen in shellScreens(scenery, empty: empty) + sheetScreens(scenery) {
            for appearance in [NSAppearance.Name.darkAqua, .aqua] {
                let bitmap = try render(
                    screen.view, size: screen.size, appearance: appearance,
                    named: screen.name)
                let luminances = try detailSurfaceLuminances(of: bitmap)
                if appearance == .darkAqua {
                    XCTAssertLessThan(
                        try XCTUnwrap(luminances.max()), 0.4,
                        "\(screen.name) surface is not dark in darkAqua")
                } else {
                    XCTAssertGreaterThan(
                        try XCTUnwrap(luminances.min()), 0.6,
                        "\(screen.name) surface is not light in aqua")
                }
            }
        }
    }

    private let shellSize = NSSize(width: 1040, height: 700)
    private let sheetSize = NSSize(width: 480, height: 380)

    private func shellScreens(_ scenery: Scenery, empty: Scenery) -> [Screen] {
        var screens = [
            Screen(name: "today", size: shellSize, view: shell(scenery, section: .today)),
            Screen(name: "garden-home", size: shellSize, view: shell(scenery, section: .garden)),
            Screen(
                name: "bed-detail", size: shellSize,
                view: shell(scenery, section: .garden, route: .bed(scenery.bedID))),
            Screen(name: "plants-home", size: shellSize, view: shell(scenery, section: .plants)),
            Screen(name: "today-empty", size: shellSize, view: shell(empty, section: .today)),
            Screen(name: "garden-empty", size: shellSize, view: shell(empty, section: .garden)),
            Screen(name: "plants-empty", size: shellSize, view: shell(empty, section: .plants)),
        ]
        if let identity = scenery.plantIdentity {
            screens.append(
                Screen(
                    name: "plant-page", size: shellSize,
                    view: shell(scenery, section: .plants, route: .plant(identity))))
        }
        if let plantingID = scenery.plantingID {
            screens.append(
                Screen(
                    name: "planting-detail", size: shellSize,
                    view: shell(scenery, section: .garden, route: .planting(plantingID))))
        }
        return screens
    }

    private func sheetScreens(_ scenery: Scenery) -> [Screen] {
        var screens = [
            Screen(
                name: "sheet-add-planting", size: sheetSize,
                view: AnyView(
                    AddPlantingSheet(context: scenery.context, bedID: scenery.bedID) {})),
            Screen(
                name: "sheet-add-seed-lot", size: sheetSize,
                view: AnyView(AddSeedLotSheet(context: scenery.context) {})),
            Screen(
                name: "sheet-log-observation", size: sheetSize,
                view: AnyView(
                    LogObservationSheet(context: scenery.context, target: .bed(scenery.bedID)) {})),
            Screen(
                name: "sheet-tasks", size: sheetSize,
                view: AnyView(TasksSheet(context: scenery.context) {})),
            Screen(
                name: "sheet-add-task", size: sheetSize,
                view: AnyView(AddTaskSheet(context: scenery.context) {})),
        ]
        if let plantingID = scenery.plantingID {
            screens.append(
                Screen(
                    name: "sheet-record-harvest", size: sheetSize,
                    view: AnyView(
                        RecordHarvestSheet(context: scenery.context, plantingID: plantingID) {})))
        }
        return screens
    }

    private func shell(
        _ scenery: Scenery, section: AppSection, route: SectionRoute? = nil
    ) -> AnyView {
        AnyView(
            CroftShell(
                gardenStore: scenery.gardenStore,
                initialSection: section,
                initialRoute: route
            )
            .environment(\.appStores, scenery.stores)
        )
    }

    private func makeScenery(seeded: Bool = true) throws -> Scenery {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let database = try AppDatabase.open(at: directory.appendingPathComponent("croft.sqlite"))
        let knowledge = seeded ? openKnowledge(in: directory) : nil
        let stores = AppStores(database: database, knowledgeDatabase: knowledge)
        let gardenStore = GardenStore(database: database)
        let context = CaptureContext(
            personal: database,
            knowledge: knowledge,
            photos: PhotoStore(baseURL: directory.appendingPathComponent("Photos")),
            defaults: CaptureDefaults()
        )

        var bedID = Bed.ID.generate()
        var plantingID: Planting.ID?
        var plantIdentity: PlantIdentity?
        if seeded {
            gardenStore.addGarden(named: "Audit Garden")
            let gardenID = try XCTUnwrap(gardenStore.overview?.gardens.first?.garden.id)
            gardenStore.addBed(named: "Audit Bed", kind: .raised, in: .garden(gardenID))
            bedID = try XCTUnwrap(gardenStore.overview?.gardens.first?.beds.first?.bed.id)

            let task = AddTaskForm(context: context)
            task.type = .water
            task.title = "Water the audit bed"
            task.dueOn = Date(timeIntervalSinceNow: -86_400 * 3)
            try task.save()

            if let choice = try context.plantChoices().first {
                plantIdentity = choice.identity
                let form = AddPlantingForm(context: context, bedID: bedID)
                form.identity = choice.identity
                plantingID = try form.save().id
            }
            gardenStore.refresh()
        }

        let scenery = Scenery(
            directory: directory,
            stores: stores,
            gardenStore: gardenStore,
            context: context,
            bedID: bedID,
            plantingID: plantingID,
            plantIdentity: plantIdentity
        )
        cleanupDirectories.append(directory)
        return scenery
    }

    private func openKnowledge(in directory: URL) -> AppDatabase? {
        guard
            let bundled = Bundle(for: AppearanceAuditTests.self)
                .url(forResource: "knowledge", withExtension: "sqlite")
        else {
            return nil
        }
        let copy = directory.appendingPathComponent("knowledge.sqlite")
        do {
            try FileManager.default.copyItem(at: bundled, to: copy)
            return try AppDatabase.open(at: copy)
        } catch {
            return nil
        }
    }

    private func render(
        _ view: AnyView, size: NSSize, appearance name: NSAppearance.Name, named: String
    ) throws -> NSBitmapImageRep {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: name)
        let hosting = NSHostingView(rootView: view)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(1))

        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        saveAuditImage(bitmap, named: "\(named)-\(name.rawValue)")
        window.contentView = nil
        return bitmap
    }

    private func saveAuditImage(_ bitmap: NSBitmapImageRep, named: String) {
        guard let base = ProcessInfo.processInfo.environment["APPEARANCE_AUDIT_DIR"],
            let data = bitmap.representation(using: .png, properties: [:])
        else {
            return
        }
        let directory = URL(fileURLWithPath: base, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        try? data.write(to: directory.appendingPathComponent("\(named).png"))
    }

    private func detailSurfaceLuminances(of bitmap: NSBitmapImageRep) throws -> [CGFloat] {
        let inset = 6
        let points = [
            (bitmap.pixelsWide / 2, bitmap.pixelsHigh - inset),
            (bitmap.pixelsWide * 13 / 20, bitmap.pixelsHigh - inset),
        ]
        var luminances: [CGFloat] = []
        for point in points {
            let color = try XCTUnwrap(bitmap.colorAt(x: point.0, y: point.1))
            let srgb = try XCTUnwrap(color.usingColorSpace(.sRGB))
            luminances.append(
                0.2126 * srgb.redComponent
                    + 0.7152 * srgb.greenComponent
                    + 0.0722 * srgb.blueComponent
            )
        }
        return luminances
    }
}
