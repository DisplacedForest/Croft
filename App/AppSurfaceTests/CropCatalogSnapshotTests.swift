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

    func testVarietalsUnderAnImagedCropAlwaysCarryAnImage() throws {
        let catalog = try snapshotLoader().cropCatalog()
        let orphaned = catalog.crops
            .filter { $0.crop.imageFile != nil }
            .flatMap(\.varietals)
            .filter { $0.imageFile == nil }
        XCTAssertTrue(
            orphaned.isEmpty,
            "varietals missing the species fallback image: \(orphaned.map(\.displayName))")
    }
}
