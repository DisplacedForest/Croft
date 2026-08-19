import Persistence
import PlantCatalog
import XCTest

@MainActor
final class CropCatalogSnapshotTests: XCTestCase {
    private func snapshotLoader() throws -> PlantPageLoader {
        let bundled = try XCTUnwrap(
            Bundle(for: CropCatalogSnapshotTests.self)
                .url(forResource: "knowledge", withExtension: "sqlite"))
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        let copy = directory.appendingPathComponent("knowledge.sqlite")
        try FileManager.default.copyItem(at: bundled, to: copy)
        let knowledge = try AppDatabase.open(at: copy)
        let personal = try AppDatabase.open(
            at: directory.appendingPathComponent("personal.sqlite"))
        return PlantPageLoader(knowledge: knowledge, personal: personal)
    }

    func testEveryCultivarInTheSnapshotLandsInExactlyOneCrop() throws {
        let loader = try snapshotLoader()
        let catalog = try loader.cropCatalog()
        let flat = try loader.listItems()

        XCTAssertFalse(catalog.isEmpty)
        XCTAssertEqual(catalog.crops.count, flat.count { $0.kind == .species })
        let groupedIDs = catalog.crops.flatMap(\.varietals).map(\.id)
        XCTAssertEqual(Set(groupedIDs).count, groupedIDs.count)
        XCTAssertEqual(
            groupedIDs.sorted(),
            flat.filter { $0.kind == .cultivar }.map(\.id).sorted())
    }

    func testNoCultivarAppearsAtTheCropLevel() throws {
        let catalog = try snapshotLoader().cropCatalog()
        XCTAssertTrue(catalog.crops.allSatisfy { $0.crop.kind == .species })
    }

    func testVarietalRowsNeverBorrowTheSpeciesImage() throws {
        let catalog = try snapshotLoader().cropCatalog()
        let borrowed = catalog.crops.flatMap { group in
            group.varietals.filter { varietal in
                varietal.imageFile != nil && varietal.imageFile == group.crop.imageFile
            }
        }
        XCTAssertTrue(
            borrowed.isEmpty,
            "varietal rows repeating the species image: \(borrowed.map(\.displayName))")
        let owned = catalog.crops.flatMap(\.varietals).count { $0.imageFile != nil }
        XCTAssertGreaterThan(owned, 0)
    }
}
