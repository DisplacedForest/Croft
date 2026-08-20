import AppKit
import GardenModel
import Persistence
import SwiftUI
import XCTest

@MainActor
final class PropertySetupDismissalTests: XCTestCase {
    private var suiteName = ""
    private var suite: UserDefaults!
    private var directory: URL!
    private var window: NSWindow!

    override func setUp() async throws {
        suiteName = "setup-dismissal-tests-\(UUID().uuidString)"
        suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        window?.close()
        window = nil
        suite.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
    }

    private func hostShell(
        form: PropertyDetailsForm? = nil
    ) throws -> PropertySetupDefaults {
        let database = try AppDatabase.open(
            at: directory.appendingPathComponent("croft.sqlite"))
        let defaults = PropertySetupDefaults(store: suite)
        let shell = AnyView(
            CroftShell(
                gardenStore: GardenStore(database: database),
                setupDefaults: defaults,
                propertyForm: form
            )
            .environment(
                \.appStores, AppStores(database: database, knowledgeDatabase: nil))
        )
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let hosting = NSHostingView(rootView: shell)
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        return defaults
    }

    @discardableResult
    private func pump(
        timeout: TimeInterval = 5, until condition: () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        return condition()
    }

    func testProgrammaticTeardownLeavesSetupUnprompted() throws {
        let defaults = try hostShell()
        XCTAssertTrue(
            pump(until: { window.attachedSheet != nil }),
            "the first-run setup sheet never presented")

        let sheet = try XCTUnwrap(window.attachedSheet)
        window.endSheet(sheet)
        pump(timeout: 2, until: { window.attachedSheet == nil })

        XCTAssertFalse(defaults.hasBeenPrompted)
        XCTAssertTrue(PropertySetupGate.shouldOffer(property: nil, defaults: defaults))
    }

    func testDeclinedOutcomeCommitsWhenTheSheetDismisses() throws {
        let database = try AppDatabase.open(
            at: directory.appendingPathComponent("form.sqlite"))
        let defaults = PropertySetupDefaults(store: suite)
        let form = PropertyDetailsForm(database: database, defaults: defaults)
        form.load()
        _ = try hostShell(form: form)
        XCTAssertTrue(
            pump(until: { window.attachedSheet != nil }),
            "the first-run setup sheet never presented")

        form.declineSetup()
        let sheet = try XCTUnwrap(window.attachedSheet)
        window.endSheet(sheet)
        pump(timeout: 2, until: { window.attachedSheet == nil })

        XCTAssertTrue(
            pump(timeout: 2, until: { defaults.hasBeenPrompted }),
            "the recorded decline was not committed on dismissal")
        XCTAssertFalse(PropertySetupGate.shouldOffer(property: nil, defaults: defaults))
    }
}
