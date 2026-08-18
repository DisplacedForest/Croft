import AppKit
import Persistence
import SwiftUI
import XCTest

import enum Domain.BedKind
import struct Domain.Cultivar
import struct Domain.Genus
import struct Domain.Harvest
import struct Domain.Observation
import struct Domain.PlantFamily
import struct Domain.Planting
import struct Domain.Quantity
import struct Domain.Species

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

    private func seedSeason(
        in database: AppDatabase,
        directory: URL,
        gardenStore: GardenStore
    ) throws -> Planting {
        gardenStore.addGarden(named: "Timeline Garden")
        let gardenID = try XCTUnwrap(gardenStore.overview?.gardens.first?.garden.id)
        gardenStore.addBed(named: "Timeline Bed", kind: .raised, in: .garden(gardenID))
        let bed = try XCTUnwrap(gardenStore.overview?.gardens.first?.beds.first?.bed)

        let family = PlantFamily(name: "Solanaceae")
        let genus = Genus(familyID: family.id, name: "Solanum")
        let species = Species(
            genusID: genus.id, scientificName: "Solanum lycopersicum", commonNames: ["Tomato"])
        let cultivar = Cultivar(speciesID: species.id, name: "Brandywine")
        try PlantFamilyRepository(database).insert(family)
        try GenusRepository(database).insert(genus)
        try SpeciesRepository(database).insert(species)
        try CultivarRepository(database).insert(cultivar)

        let planted = Date(timeIntervalSinceNow: -120 * 86_400)
        let planting = Planting(
            identity: .cultivar(cultivar.id),
            bedID: bed.id,
            plantedOn: planted,
            status: .active
        )
        try PlantingRepository(database).insert(planting)
        let photos = PhotoStore(baseURL: directory.appendingPathComponent("Photos"))
        let observations = ObservationRepository(database, photos: photos)
        try observations.insert(
            Observation(
                target: .planting(planting.id),
                observedAt: planted.addingTimeInterval(7 * 86_400),
                stage: .germinated))
        try observations.insert(
            Observation(
                target: .planting(planting.id),
                observedAt: planted.addingTimeInterval(60 * 86_400),
                notes: "Tied the main stem twice."))
        try HarvestRepository(database).insert(
            Harvest(
                plantingID: planting.id,
                harvestedOn: planted.addingTimeInterval(110 * 86_400),
                yield: .measured(try Quantity(amount: 410, unit: .gram)),
                harvestedPart: .fruit))
        return planting
    }

    func testPushedPlantingTimelineRendersInBothAppearances() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = try AppDatabase.open(at: directory.appendingPathComponent("croft.sqlite"))
        let gardenStore = GardenStore(database: database)
        let planting = try seedSeason(
            in: database, directory: directory, gardenStore: gardenStore)

        let shell = AnyView(
            CroftShell(
                gardenStore: gardenStore,
                initialSection: .garden,
                initialRoute: .planting(planting.id)
            )
            .environment(\.appStores, AppStores(database: database, knowledgeDatabase: nil))
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            window.appearance = NSAppearance(named: appearance)
            let hosting = NSHostingView(rootView: shell)
            window.contentView = hosting
            hosting.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(2))
            XCTAssertNotNil(hosting.window)
        }
    }
}
