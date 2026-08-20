import AppKit
import SwiftUI
import XCTest

@MainActor
final class UpdaterPolicyTests: XCTestCase {
    func testUnsignedVerdictKeepsTheUpdaterStoppedWithAnExplanation() {
        let policy = UpdaterPolicy.resolve(bundleSignedForUpdates: false)
        XCTAssertFalse(policy.startsUpdater)
        XCTAssertEqual(policy.unavailableExplanation, UpdaterPolicy.unavailableMessage)
    }

    func testSignedVerdictStartsTheUpdaterWithNoExplanation() {
        let policy = UpdaterPolicy.resolve(bundleSignedForUpdates: true)
        XCTAssertTrue(policy.startsUpdater)
        XCTAssertNil(policy.unavailableExplanation)
    }

    func testMenuContentGrowsByTheExplanationWhenUnsigned() {
        let signed = renderedHeight(explanation: nil)
        let unsigned = renderedHeight(explanation: UpdaterPolicy.unavailableMessage)
        XCTAssertGreaterThan(
            unsigned, signed,
            "unsigned menu content should render an extra explanation line")
    }

    private func renderedHeight(explanation: String?) -> CGFloat {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 120),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let hosting = NSHostingView(
            rootView: VStack {
                UpdateCommandContent(
                    canCheckForUpdates: explanation == nil,
                    unavailableExplanation: explanation,
                    checkForUpdates: {}
                )
            })
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        return hosting.fittingSize.height
    }
}
