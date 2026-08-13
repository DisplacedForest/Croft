import XCTest

final class ShellNavigationTests: XCTestCase {
    func testSectionsSwitchAndDetailPushes() {
        let app = XCUIApplication()
        app.launch()
        let plantsTab = app.tabBars.buttons["Plants"]
        XCTAssertTrue(plantsTab.waitForExistence(timeout: 5))
        plantsTab.tap()
        XCTAssertTrue(
            app.staticTexts["A field guide to what you grow."].waitForExistence(timeout: 5))
        app.buttons["Preview a detail screen"].tap()
        XCTAssertTrue(app.staticTexts["Detail screens open here."].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        let gardenTab = app.tabBars.buttons["Garden"]
        gardenTab.tap()
        XCTAssertTrue(app.navigationBars["Garden"].waitForExistence(timeout: 5))
    }
}
