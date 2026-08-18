import Domain
import Foundation
import Persistence

public enum GardenEditError: Error, Equatable {
    case blankName
}

public struct GardenEditor: Sendable {
    private let structures: GardenStructureRepository

    public init(_ database: AppDatabase) {
        structures = GardenStructureRepository(database)
    }

    @discardableResult
    public func addGarden(named name: String) throws -> Garden {
        let garden = Garden(name: try trimmed(name))
        try structures.create(garden, in: try homeProperty().id)
        return garden
    }

    @discardableResult
    public func addGrowingArea(named name: String, in gardenID: Garden.ID) throws -> GrowingArea {
        let area = GrowingArea(name: try trimmed(name))
        try structures.create(area, in: gardenID)
        return area
    }

    @discardableResult
    public func addBed(named name: String, kind: BedKind, in parent: BedParent) throws -> Bed {
        let bed = Bed(name: try trimmed(name), kind: kind)
        try structures.create(bed, in: parent)
        return bed
    }

    public func renameGarden(_ id: Garden.ID, to name: String) throws {
        try structures.renameGarden(id, to: try trimmed(name))
    }

    public func renameGrowingArea(_ id: GrowingArea.ID, to name: String) throws {
        try structures.renameGrowingArea(id, to: try trimmed(name))
    }

    public func renameBed(_ id: Bed.ID, to name: String) throws {
        try structures.renameBed(id, to: try trimmed(name))
    }

    public func archiveGarden(_ id: Garden.ID) throws {
        try structures.setGardenArchived(id, true)
    }

    public func archiveGrowingArea(_ id: GrowingArea.ID) throws {
        try structures.setGrowingAreaArchived(id, true)
    }

    public func archiveBed(_ id: Bed.ID) throws {
        try structures.setBedArchived(id, true)
    }

    public func moveBed(_ id: Bed.ID, to parent: BedParent) throws {
        try structures.moveBed(id, to: parent)
    }

    public func moveGrowingArea(_ id: GrowingArea.ID, to gardenID: Garden.ID) throws {
        try structures.moveGrowingArea(id, to: gardenID)
    }

    @discardableResult
    public func homeProperty() throws -> Property {
        if let existing = try structures.properties(includeArchived: true).first {
            return existing
        }
        let property = Property(name: "Home")
        try structures.create(property)
        return property
    }

    private func trimmed(_ name: String) throws -> String {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw GardenEditError.blankName
        }
        return cleaned
    }
}
