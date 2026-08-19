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

    func testTheNoMatchListStillRendersTheCropRow() throws {
        let group = sampleGroup()
        let noMatch = try renderedPage(group: group, query: "zucchini")
        let matching = try renderedPage(group: group, query: "roma")
        let blank = try renderedPage(group: group, query: "")
        XCTAssertEqual(matching.rowCount, blank.rowCount)
        XCTAssertEqual(
            noMatch.rowCount, matching.rowCount,
            "the no-match page lost a row; the crop row must survive")
        XCTAssertGreaterThanOrEqual(noMatch.rowCount, 2)
        XCTAssertEqual(
            noMatch.cropBandPixels, blank.cropBandPixels,
            "the crop row band renders differently under a no-match query; something is covering it"
        )
        XCTAssertTrue(
            blank.cropRowHitReachesTheTable,
            "clicking the crop row area must reach the list")
        XCTAssertTrue(
            noMatch.cropRowHitReachesTheTable,
            "the no-match state blocks clicks on the crop row area")
    }

    private struct RenderedPage {
        let rowCount: Int
        let cropBandPixels: Data
        let cropRowHitReachesTheTable: Bool
    }

    private func renderedPage(group: CropGroup, query: String) throws -> RenderedPage {
        let page = NavigationStack {
            LoadedCropPage(group: group, query: query) { _ in }
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .aqua)
        let hosting = NSHostingView(rootView: AnyView(page))
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(1))
        let table = try XCTUnwrap(
            firstTableView(in: hosting),
            "the crop page did not render a table")
        let cropRect = try cropRowRect(of: table, in: hosting)
        let rep = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: cropRect))
        hosting.cacheDisplay(in: cropRect, to: rep)
        let pixels = try XCTUnwrap(rep.tiffRepresentation)
        let hitPoint = NSPoint(x: cropRect.midX, y: cropRect.midY)
        let hit = hosting.hitTest(hosting.convert(hitPoint, to: hosting.superview))
        var reaches = false
        var current: NSView? = hit
        while let view = current {
            if view === table || view.isDescendant(of: table) {
                reaches = true
                break
            }
            current = view.superview
        }
        return RenderedPage(
            rowCount: table.numberOfRows,
            cropBandPixels: pixels,
            cropRowHitReachesTheTable: reaches
        )
    }

    private func cropRowRect(of table: NSTableView, in hosting: NSView) throws -> NSRect {
        XCTAssertGreaterThanOrEqual(table.numberOfRows, 2)
        let band = table.rect(ofRow: 0).union(table.rect(ofRow: 1))
        return hosting.convert(band, from: table)
    }

    private func firstTableView(in view: NSView) -> NSTableView? {
        if let table = view as? NSTableView {
            return table
        }
        for subview in view.subviews {
            if let table = firstTableView(in: subview) {
                return table
            }
        }
        return nil
    }
}
