import AppKit
import Persistence
import SwiftUI
import XCTest

import struct Domain.Bed
import enum Domain.BedKind
import struct Domain.Genus
import struct Domain.PlantFamily
import struct Domain.Planting
import struct Domain.Species

private struct ToolbarProbeKey: EnvironmentKey {
    static let defaultValue = "unresolved"
}

extension EnvironmentValues {
    fileprivate var toolbarProbe: String {
        get { self[ToolbarProbeKey.self] }
        set { self[ToolbarProbeKey.self] = newValue }
    }
}

@MainActor
private final class ProbeRecorder {
    private(set) var sightings: [String: String] = [:]

    func record(_ tag: String, _ value: String) {
        sightings[tag] = value
    }
}

private struct ProbeView: View {
    @Environment(\.toolbarProbe) private var probe
    let tag: String
    let recorder: ProbeRecorder

    var body: some View {
        recorder.record(tag, probe)
        return Text(tag)
    }
}

private struct ProbedShell: View {
    let recorder: ProbeRecorder
    let injectionInsideContentOnly: Bool

    var body: some View {
        let shell = NavigationSplitView {
            List {
                Text("sidebar")
            }
        } detail: {
            VStack {
                ProbeView(tag: "content", recorder: recorder)
                    .environment(
                        \.toolbarProbe, injectionInsideContentOnly ? "injected" : "ignored")
            }
            .toolbar {
                Menu {
                    ProbeView(tag: "toolbarMenu", recorder: recorder)
                    Button("Act") {}
                } label: {
                    Label("Probe Menu", systemImage: "ellipsis.circle")
                }
                ProbeView(tag: "toolbarItem", recorder: recorder)
            }
        }
        if injectionInsideContentOnly {
            shell
        } else {
            shell.environment(\.toolbarProbe, "injected")
        }
    }
}

@MainActor
final class ToolbarEnvironmentTests: XCTestCase {
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

    func testToolbarContentEvaluatesAtRenderAndResolvesOuterInjections() throws {
        let recorder = ProbeRecorder()
        let window = hostedWindow(
            ProbedShell(recorder: recorder, injectionInsideContentOnly: false))
        let toolbar = try XCTUnwrap(settleToolbar(of: window))
        XCTAssertFalse(toolbar.items.isEmpty)
        XCTAssertEqual(recorder.sightings["toolbarMenu"], "injected")
        XCTAssertEqual(recorder.sightings["toolbarItem"], "injected")
    }

    func testToolbarHierarchyCannotResolveContentScopedInjections() throws {
        let recorder = ProbeRecorder()
        let window = hostedWindow(
            ProbedShell(recorder: recorder, injectionInsideContentOnly: true))
        _ = try XCTUnwrap(settleToolbar(of: window))
        XCTAssertEqual(recorder.sightings["content"], "injected")
        XCTAssertEqual(recorder.sightings["toolbarMenu"], "unresolved")
        XCTAssertEqual(recorder.sightings["toolbarItem"], "unresolved")
    }

    private struct SeededGarden {
        let store: GardenStore
        let bed: Bed
        let planting: Planting
    }

    private func seededStore() throws -> SeededGarden {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        let database = try AppDatabase.open(at: directory.appendingPathComponent("croft.sqlite"))
        let store = GardenStore(database: database)
        store.addGarden(named: "Toolbar Garden")
        let gardenID = try XCTUnwrap(store.overview?.gardens.first?.garden.id)
        store.addBed(named: "Toolbar Bed", kind: .raised, in: .garden(gardenID))
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
        return SeededGarden(store: store, bed: bed, planting: planting)
    }

    private func toolbarLabels(
        initialSection: AppSection,
        initialRoute: SectionRoute?
    ) throws -> [String] {
        let seeded = try seededStore()
        let shell = AnyView(
            CroftShell(
                gardenStore: seeded.store,
                initialSection: initialSection,
                initialRoute: initialRoute
            )
            .environment(\.appStores, nil)
        )
        let window = hostedWindow(shell)
        let toolbar = try XCTUnwrap(settleToolbar(of: window))
        return toolbar.items.map(\.label)
    }

    func testGardenHomeRealizesItsAddMenuInTheToolbarHierarchy() throws {
        let labels = try toolbarLabels(initialSection: .garden, initialRoute: nil)
        XCTAssertTrue(labels.contains("Record"), "labels were \(labels)")
        XCTAssertTrue(labels.contains("Add"), "labels were \(labels)")
    }

    func testBedDetailRealizesItsToolbarButtons() throws {
        let seeded = try seededStore()
        let labels = try toolbarLabels(for: seeded.store, route: .bed(seeded.bed.id))
        XCTAssertTrue(labels.contains("Record"), "labels were \(labels)")
        XCTAssertTrue(labels.contains("Add Planting"), "labels were \(labels)")
    }

    func testPlantingDetailRealizesItsToolbarButtons() throws {
        let seeded = try seededStore()
        let labels = try toolbarLabels(for: seeded.store, route: .planting(seeded.planting.id))
        XCTAssertTrue(labels.contains("Record"), "labels were \(labels)")
        XCTAssertTrue(labels.contains("Log Observation"), "labels were \(labels)")
        XCTAssertTrue(labels.contains("Record Harvest"), "labels were \(labels)")
    }

    private func toolbarLabels(for store: GardenStore, route: SectionRoute) throws -> [String] {
        let shell = AnyView(
            CroftShell(gardenStore: store, initialSection: .garden, initialRoute: route)
                .environment(\.appStores, nil)
        )
        let window = hostedWindow(shell)
        let toolbar = try XCTUnwrap(settleToolbar(of: window))
        return toolbar.items.map(\.label)
    }
}
