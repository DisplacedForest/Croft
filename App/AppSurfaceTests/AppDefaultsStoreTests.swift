import XCTest

@MainActor
final class AppDefaultsStoreTests: XCTestCase {
    func testReleaseChoiceIgnoresTheSuite() {
        let resolved = AppDefaultsStore.resolve(choice: .release, suite: "com.example.gate")
        XCTAssertTrue(resolved === UserDefaults.standard)
    }

    func testDevChoiceWithoutASuiteKeepsStandardDefaults() {
        XCTAssertTrue(AppDefaultsStore.resolve(choice: .dev, suite: nil) === UserDefaults.standard)
        XCTAssertTrue(AppDefaultsStore.resolve(choice: .dev, suite: "") === UserDefaults.standard)
    }

    func testDevChoiceWithASuiteUsesTheSuite() {
        let suite = "com.displacedforest.croft.tests.\(UUID().uuidString)"
        let resolved = AppDefaultsStore.resolve(choice: .dev, suite: suite)
        XCTAssertFalse(resolved === UserDefaults.standard)
        resolved.set(true, forKey: "probe")
        XCTAssertTrue(UserDefaults(suiteName: suite)?.bool(forKey: "probe") ?? false)
        resolved.removePersistentDomain(forName: suite)
    }

    func testCustomChoiceWithASuiteUsesTheSuite() {
        let suite = "com.displacedforest.croft.tests.\(UUID().uuidString)"
        let resolved = AppDefaultsStore.resolve(choice: .custom("/tmp/x.sqlite"), suite: suite)
        XCTAssertFalse(resolved === UserDefaults.standard)
        resolved.removePersistentDomain(forName: suite)
    }
}
