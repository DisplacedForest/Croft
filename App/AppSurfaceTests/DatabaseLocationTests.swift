import Persistence
import XCTest

@MainActor
final class DatabaseLocationTests: XCTestCase {
    func testDeveloperIDVerdictKeepsTheReleasePathAndIgnoresTheOverride() {
        XCTAssertEqual(
            DatabaseLocation.choose(developerIDSigned: true, override: "/tmp/elsewhere.sqlite"),
            .release
        )
        XCTAssertEqual(DatabaseLocation.choose(developerIDSigned: true, override: nil), .release)
    }

    func testUnsignedVerdictUsesTheDevDatabase() {
        XCTAssertEqual(DatabaseLocation.choose(developerIDSigned: false, override: nil), .dev)
        XCTAssertEqual(DatabaseLocation.choose(developerIDSigned: false, override: ""), .dev)
    }

    func testUnsignedVerdictHonorsTheOverride() {
        XCTAssertEqual(
            DatabaseLocation.choose(developerIDSigned: false, override: "/tmp/chosen.sqlite"),
            .custom("/tmp/chosen.sqlite")
        )
    }

    func testReleaseURLMatchesTheHistoricalPath() throws {
        XCTAssertEqual(try DatabaseLocation.url(for: .release), try AppDatabase.defaultURL())
    }

    func testDevURLIsTheDevFileBesideTheReleaseDatabase() throws {
        let dev = try DatabaseLocation.url(for: .dev)
        XCTAssertEqual(dev.lastPathComponent, DatabaseLocation.devFileName)
        XCTAssertEqual(
            dev.deletingLastPathComponent(),
            try AppDatabase.defaultURL().deletingLastPathComponent()
        )
    }

    func testCustomURLPointsAtTheChosenFile() throws {
        XCTAssertEqual(
            try DatabaseLocation.url(for: .custom("/tmp/chosen.sqlite")).path,
            "/tmp/chosen.sqlite"
        )
    }

    func testStrandedDatabaseMapsToTheUpdateMessage() {
        let message = GardenStore.startupMessage(
            for: MigrationError.unknownApplied(["v999-future"]))
        XCTAssertEqual(message, GardenStore.newerDatabaseMessage)
    }

    func testOtherErrorsKeepTheGenericStartupCopy() {
        struct Broken: Error {}
        let message = GardenStore.startupMessage(for: Broken())
        XCTAssertTrue(message.hasPrefix("Croft couldn't open its garden records."))
    }
}
