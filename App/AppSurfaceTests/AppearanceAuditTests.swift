import AppKit
import Capture
import Design
import GardenModel
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
import struct Domain.Species

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
        let cropSpeciesID: Species.ID?
    }

    private nonisolated(unsafe) var cleanupDirectories: [URL] = []
    private var referenceSwatches: [String: NSColor] = [:]

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
                let inset = 6
                let points = [
                    (bitmap.pixelsWide / 2, bitmap.pixelsHigh - inset),
                    (bitmap.pixelsWide * 13 / 20, bitmap.pixelsHigh - inset),
                ]
                try assertTokenSurface(
                    bitmap, at: points, appearance: appearance, screen: screen.name)
            }
        }
    }

    func testIntrinsicSizeContentStillFillsTheTokenSurface() throws {
        for appearance in [NSAppearance.Name.darkAqua, .aqua] {
            let bitmap = try render(
                AnyView(ProgressView().croftScreenSurface()),
                size: sheetSize, appearance: appearance, named: "surface-fill")
            let inset = 6
            let points = [
                (inset, inset),
                (bitmap.pixelsWide - 1 - inset, inset),
                (inset, bitmap.pixelsHigh - 1 - inset),
                (bitmap.pixelsWide - 1 - inset, bitmap.pixelsHigh - 1 - inset),
            ]
            try assertSurfacePrimary(
                bitmap, at: points, appearance: appearance, screen: "surface-fill")
        }
    }

    private let shellSize = NSSize(width: 1040, height: 700)
    private let sheetSize = NSSize(width: 480, height: 380)
}

extension AppearanceAuditTests {
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
        if let cropSpeciesID = scenery.cropSpeciesID {
            screens.append(
                Screen(
                    name: "crop-varietals",
                    size: shellSize,
                    view: shell(scenery, section: .plants, route: .crop(cropSpeciesID))))
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
                    AddPlantingSheet(
                        context: scenery.context,
                        intent: AddPlantingIntent(bedID: scenery.bedID)
                    ) {})),
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
        screens.append(
            Screen(
                name: "sheet-new-garden", size: sheetSize,
                view: AnyView(NameEntrySheet(title: "New Garden", confirm: "Create") { _ in })))
        screens.append(
            Screen(
                name: "sheet-new-bed", size: sheetSize,
                view: AnyView(NewBedSheet { _, _ in })))
        screens.append(
            Screen(
                name: "sheet-property-setup",
                size: NSSize(width: 480, height: 600),
                view: AnyView(
                    PropertySetupSheet(form: PropertyDetailsForm(database: scenery.stores.database))
                )))
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

        let cropSpeciesID = (try? stores.plantPages.cropCatalog())?
            .crops.first { $0.varietalCount > 0 }?
            .speciesID
        let scenery = Scenery(
            directory: directory,
            stores: stores,
            gardenStore: gardenStore,
            context: context,
            bedID: bedID,
            plantingID: plantingID,
            plantIdentity: plantIdentity,
            cropSpeciesID: seeded ? cropSpeciesID : nil
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

    private func assertSurfacePrimary(
        _ bitmap: NSBitmapImageRep,
        at points: [(Int, Int)],
        appearance name: NSAppearance.Name,
        screen: String
    ) throws {
        let expected = try renderedToken(.surfacePrimary, in: name)
        for point in points {
            let srgb = try sample(bitmap, at: point)
            let label = "\(screen) at \(point) in \(name.rawValue)"
            XCTAssertEqual(srgb.redComponent, expected.redComponent, accuracy: 0.01, label)
            XCTAssertEqual(srgb.greenComponent, expected.greenComponent, accuracy: 0.01, label)
            XCTAssertEqual(srgb.blueComponent, expected.blueComponent, accuracy: 0.01, label)
        }
    }

    private func assertTokenSurface(
        _ bitmap: NSBitmapImageRep,
        at points: [(Int, Int)],
        appearance name: NSAppearance.Name,
        screen: String
    ) throws {
        let expected = [
            try renderedToken(.surfacePrimary, in: name),
            try renderedToken(.surfaceSecondary, in: name),
        ]
        for point in points {
            let srgb = try sample(bitmap, at: point)
            let matches = expected.contains { token in
                abs(srgb.redComponent - token.redComponent) <= 0.01
                    && abs(srgb.greenComponent - token.greenComponent) <= 0.01
                    && abs(srgb.blueComponent - token.blueComponent) <= 0.01
            }
            XCTAssertTrue(
                matches,
                "\(screen) at \(point) in \(name.rawValue) is not on a token surface: "
                    + "(\(srgb.redComponent), \(srgb.greenComponent), \(srgb.blueComponent))")
        }
    }

    private func sample(_ bitmap: NSBitmapImageRep, at point: (Int, Int)) throws -> NSColor {
        let color = try XCTUnwrap(bitmap.colorAt(x: point.0, y: point.1))
        return try XCTUnwrap(color.usingColorSpace(.sRGB))
    }

    private func renderedToken(
        _ token: ColorToken, in name: NSAppearance.Name
    ) throws -> NSColor {
        let key = "\(token.rawValue)-\(name.rawValue)"
        if let cached = referenceSwatches[key] {
            return cached
        }
        let bitmap = try render(
            AnyView(Color(token.rawValue, bundle: DesignResources.bundle)),
            size: NSSize(width: 64, height: 64),
            appearance: name, named: "surface-reference")
        let srgb = try sample(bitmap, at: (bitmap.pixelsWide / 2, bitmap.pixelsHigh / 2))
        referenceSwatches[key] = srgb
        return srgb
    }
}
