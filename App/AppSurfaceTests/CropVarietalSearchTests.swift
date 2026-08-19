import AppKit
import PlantCatalog
import SwiftUI
import XCTest

import struct Domain.Cultivar
import enum Domain.PlantIdentity
import struct Domain.Species

@MainActor
final class CropVarietalSearchTests: XCTestCase {
    private func sampleGroup() -> CropGroup {
        let speciesID = Species.ID(rawValue: "species:solanum-lycopersicum")
        let crop = PlantListItem(
            id: speciesID.rawValue,
            identity: .species(speciesID),
            kind: .species,
            displayName: "Tomato",
            scientificName: "Solanum lycopersicum"
        )
        let roma = PlantListItem(
            id: "cultivar:solanum-lycopersicum/roma",
            identity: .cultivar(Cultivar.ID(rawValue: "cultivar:solanum-lycopersicum/roma")),
            kind: .cultivar,
            displayName: "Roma",
            scientificName: "Solanum lycopersicum 'Roma'",
            otherNames: ["Tomato - Roma"]
        )
        return CropGroup(crop: crop, varietals: [roma])
    }

    func testANoMatchQueryKeepsTheCropRowAndMarksTheVarietalSection() {
        let content = CropPageContent.build(group: sampleGroup(), query: "zucchini")
        XCTAssertEqual(content.cropRow.displayName, "Tomato")
        XCTAssertEqual(content.varietals, .noMatches(query: "zucchini"))
    }

    func testABlankQueryShowsEveryVarietalRow() {
        let group = sampleGroup()
        for query in ["", "   ", "\n"] {
            let content = CropPageContent.build(group: group, query: query)
            XCTAssertEqual(content.cropRow.displayName, "Tomato")
            XCTAssertEqual(content.varietals, .rows(group.varietals))
        }
    }

    func testAMatchingQueryFiltersTheRows() {
        let content = CropPageContent.build(group: sampleGroup(), query: "Tomato - Roma")
        XCTAssertEqual(content.varietals, .rows(sampleGroup().varietals))
    }

    func testTheNoMatchListStillHostsTheCropRow() {
        let group = sampleGroup()
        let content = CropPageContent.build(group: group, query: "zucchini")
        let list = CropVarietalsList(content: content, group: group) { _ in }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let hosting = NSHostingView(rootView: AnyView(list))
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(1))
        XCTAssertNotNil(hosting.window)
        XCTAssertEqual(content.cropRow.identity, group.crop.identity)
    }
}
