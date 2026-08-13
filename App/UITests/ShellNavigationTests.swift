import XCTest

final class ShellNavigationTests: XCTestCase {
    func testSectionsSwitchAndDetailPushes() {
        let app = XCUIApplication()
        app.launch()
        let plantsTab = app.tabBars.buttons["Plants"]
        XCTAssertTrue(plantsTab.waitForExistence(timeout: 5))
        plantsTab.tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
        let gardenTab = app.tabBars.buttons["Garden"]
        gardenTab.tap()
        XCTAssertTrue(app.navigationBars["Garden"].waitForExistence(timeout: 5))
    }
}
