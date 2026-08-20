import XCTest

final class SeasonGateWalkthroughTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        let environment = ProcessInfo.processInfo.environment
        for key in ["CROFT_DATABASE_PATH", "CROFT_DEFAULTS_SUITE"] {
            if let value = environment[key] {
                app.launchEnvironment[key] = value
            }
        }
        app.launch()
        app.activate()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    override func record(_ issue: XCTIssue) {
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "ui-tree"
        tree.lifetime = .keepAlways
        add(tree)
        capture("failure")
        super.record(issue)
    }

    func testSeasonGateWalkthrough() throws {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        moveWindowToMainDisplay()
        capture("01-launch")
        completePropertySetupIfOffered()
        browsePlantableList()
        planPlantingAndReadRotationWarning()
        logStageAwayFromThePlanting()
        readTodayHarvestFlag()
        recordHarvest(amount: "850", unit: "Grams", plantingContains: "South", onNextDay: false)
        recordHarvest(amount: "2", unit: "Pounds", plantingContains: "South", onNextDay: true)
        readHarvestTotals()
    }

    private func completePropertySetupIfOffered() {
        let heading = app.staticTexts["Set up your property"]
        guard heading.waitForExistence(timeout: 5) else {
            return
        }
        capture("02-property-setup-offered")
        let latitude = field("Latitude")
        XCTAssertTrue(latitude.waitForExistence(timeout: 5))
        enter("44.98", into: latitude)
        enter("-93.26", into: field("Longitude"))
        if field("Zone").exists {
            enter("5", into: field("Zone"))
        }
        pickOption("May", inPickerNamed: "Last frost")
        pickOption("10", inPickerNamed: "Day")
        pickOption("October", inPickerNamed: "First frost")
        pickOption("1", inPickerNamed: "Day")
        capture("03-property-setup-filled")
        app.buttons["Save"].firstMatch.click()
        XCTAssertFalse(heading.waitForExistence(timeout: 3))
        capture("04-property-setup-saved")
    }

    private func browsePlantableList() {
        selectSection("Plants")
        let tomato = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Tomato'")
        ).firstMatch
        XCTAssertTrue(tomato.waitForExistence(timeout: 10))
        capture("05-plantable-list")
        tomato.click()
        XCTAssertTrue(app.staticTexts["Varietals"].waitForExistence(timeout: 5))
        capture("06-crop-page")
    }

    private func planPlantingAndReadRotationWarning() {
        selectSection("Garden")
        clickElement(containing: "North Bed")
        XCTAssertTrue(awaitWindowTitle("North Bed", timeout: 5))
        let add = app.buttons["Add Planting"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        let search = field("Search plants")
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        enter("Brandywine", into: search)
        let row = app.staticTexts["Brandywine"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.click()
        pickOption(containing: "North Bed", inPickerNamed: "Bed")
        let warning = app.staticTexts.containing(
            NSPredicate(format: "value CONTAINS 'was here in' OR label CONTAINS 'was here in'")
        ).firstMatch
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        capture("07-rotation-warning")
        app.buttons["Plant"].firstMatch.click()
        XCTAssertFalse(search.waitForExistence(timeout: 3))
        capture("08-planting-saved")
    }

    private func logStageAwayFromThePlanting() {
        selectSection("Today")
        app.activate()
        let record = app.menuButtons.matching(
            NSPredicate(format: "identifier == 'square.and.pencil' OR label == 'Record'")
        ).firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.click()
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.enter, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["Log Observation"].waitForExistence(timeout: 5))
        pickOption(containing: "South", inPickerNamed: "About")
        pickOption("First Flower", inPickerNamed: "Stage")
        capture("09-stage-logged-from-today")
        app.buttons["Save"].firstMatch.click()
        XCTAssertFalse(app.staticTexts["Log Observation"].waitForExistence(timeout: 3))
    }

    private func readTodayHarvestFlag() {
        selectSection("Today")
        let flag = app.staticTexts.containing(
            NSPredicate(
                format:
                    "value CONTAINS 'past expected maturity' OR label CONTAINS 'past expected maturity'"
            )
        ).firstMatch
        XCTAssertTrue(flag.waitForExistence(timeout: 10))
        capture("10-today-harvest-flag")
    }

    private func recordHarvest(
        amount: String,
        unit: String,
        plantingContains: String,
        onNextDay: Bool
    ) {
        openPlantingDetail(bed: plantingContains)
        let record = app.buttons["Record Harvest"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.click()
        XCTAssertTrue(app.staticTexts["Record Harvest"].waitForExistence(timeout: 5))
        let quantity = field("Quantity")
        XCTAssertTrue(quantity.waitForExistence(timeout: 5))
        enter(amount, into: quantity)
        selectUnit(unit)
        if onNextDay {
            advanceHarvestDateOneDay()
        }
        capture("11-harvest-\(unit.lowercased())")
        app.buttons["Save"].firstMatch.click()
        XCTAssertFalse(quantity.waitForExistence(timeout: 3))
    }

    private func openPlantingDetail(bed: String) {
        selectSection("Garden")
        clickElement(containing: "\(bed) Bed")
        clickElement(containing: "Brandywine")
    }

    private func readHarvestTotals() {
        openPlantingDetail(bed: "South")
        let totals = app.staticTexts.containing(
            NSPredicate(format: "value CONTAINS 'harvest' OR label CONTAINS 'harvest'")
        ).firstMatch
        XCTAssertTrue(totals.waitForExistence(timeout: 5))
        capture("12-harvest-totals")
    }
}

extension SeasonGateWalkthroughTests {
    private func moveWindowToMainDisplay() {
        let window = app.windows.firstMatch
        let frame = window.frame
        guard frame.minX < 0 || frame.minX > 600 || frame.minY < 0 || frame.minY > 600 else {
            return
        }
        let grab = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.015))
        let destination = grab.withOffset(
            CGVector(dx: 120 + frame.width / 2 - frame.midX, dy: 140 - frame.minY - 15))
        grab.press(forDuration: 0.3, thenDragTo: destination)
        RunLoop.current.run(until: Date().addingTimeInterval(1))
    }

    private func clickElement(containing fragment: String, timeout: TimeInterval = 5) {
        let format = "label CONTAINS %@ OR value CONTAINS %@ OR title CONTAINS %@"
        let button = app.buttons.containing(
            NSPredicate(format: format, fragment, fragment, fragment)
        ).firstMatch
        if button.waitForExistence(timeout: timeout) {
            button.click()
            return
        }
        let text = app.staticTexts.containing(
            NSPredicate(format: format, fragment, fragment, fragment)
        ).firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: timeout))
        text.click()
    }

    private func field(_ placeholder: String) -> XCUIElement {
        let format = "placeholderValue == %@ OR label == %@ OR identifier == %@"
        let text = app.textFields.matching(
            NSPredicate(format: format, placeholder, placeholder, placeholder)
        ).firstMatch
        if text.exists {
            return text
        }
        let search = app.searchFields.matching(
            NSPredicate(format: format, placeholder, placeholder, placeholder)
        ).firstMatch
        if search.exists {
            return search
        }
        return text
    }

    private func selectSection(_ title: String) {
        for _ in 0..<4 {
            if awaitWindowTitle(title, timeout: 1) {
                return
            }
            if !app.outlines.firstMatch.exists {
                let toggle = app.buttons.matching(
                    NSPredicate(format: "label CONTAINS 'Sidebar'")
                ).firstMatch
                if toggle.waitForExistence(timeout: 2) {
                    toggle.click()
                }
            }
            let sidebarRow = app.outlines.staticTexts[title].firstMatch
            XCTAssertTrue(sidebarRow.waitForExistence(timeout: 5))
            sidebarRow.click()
            if awaitWindowTitle(title, timeout: 3) {
                return
            }
        }
        XCTAssertTrue(awaitWindowTitle(title, timeout: 1))
    }

    private func awaitWindowTitle(_ title: String, timeout: TimeInterval) -> Bool {
        app.windows.matching(NSPredicate(format: "title == %@", title)).firstMatch
            .waitForExistence(timeout: timeout)
    }

    private func pickOption(_ option: String, inPickerNamed picker: String) {
        guard
            let control = firstExisting(
                app.popUpButtons[picker],
                app.menuButtons[picker],
                app.buttons[picker]
            )
        else {
            return
        }
        openAndClick(app.menuItems[option].firstMatch, byClicking: control)
    }

    private func openAndClick(_ item: XCUIElement, byClicking opener: XCUIElement) {
        for _ in 0..<4 {
            opener.click()
            if waitUntilPresented(item, timeout: 2) {
                break
            }
        }
        XCTAssertTrue(waitUntilPresented(item, timeout: 2))
        item.click()
    }

    private func waitUntilPresented(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if element.exists && element.frame.width > 1 && element.frame.height > 1 {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        } while Date() < deadline
        return false
    }

    private func pickOption(containing fragment: String, inPickerNamed picker: String) {
        guard
            let control = firstExisting(
                app.popUpButtons[picker],
                app.menuButtons[picker],
                app.buttons[picker]
            )
        else {
            XCTFail("no picker named \(picker)")
            return
        }
        let choice = app.menuItems.containing(
            NSPredicate(format: "title CONTAINS %@ OR label CONTAINS %@", fragment, fragment)
        ).firstMatch
        openAndClick(choice, byClicking: control)
    }

    private func selectUnit(_ unit: String) {
        let known = ["Grams", "Pounds", "Kilograms", "Ounces"]
        if let control = firstExisting(
            app.popUpButtons[unit],
            contains: known.map { app.popUpButtons[$0] }
        ) {
            if control.label == unit || control.value as? String == unit {
                return
            }
            control.click()
            let option = app.menuItems[unit].firstMatch
            XCTAssertTrue(option.waitForExistence(timeout: 5))
            option.click()
            return
        }
        let anyPopUp = app.popUpButtons.containing(
            NSPredicate(format: "value IN %@", known)
        ).firstMatch
        XCTAssertTrue(anyPopUp.waitForExistence(timeout: 5))
        if anyPopUp.value as? String != unit {
            anyPopUp.click()
            let option = app.menuItems[unit].firstMatch
            XCTAssertTrue(option.waitForExistence(timeout: 5))
            option.click()
        }
    }

    private func advanceHarvestDateOneDay() {
        let picker = app.datePickers.firstMatch
        guard picker.waitForExistence(timeout: 5) else {
            return
        }
        let increment = picker.incrementArrows.firstMatch
        if increment.exists {
            picker.click()
            increment.click()
            return
        }
        picker.click()
        picker.typeKey(.upArrow, modifierFlags: [])
    }

    private func enter(_ text: String, into field: XCUIElement) {
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText(text)
    }

    private func firstExisting(_ candidates: XCUIElement...) -> XCUIElement? {
        firstExisting(candidates[0], contains: Array(candidates.dropFirst()))
    }

    private func firstExisting(_ head: XCUIElement, contains rest: [XCUIElement]) -> XCUIElement? {
        for element in [head] + rest where element.waitForExistence(timeout: 2) {
            return element
        }
        return nil
    }

    private func capture(_ name: String) {
        let window = app.windows.firstMatch
        let shot = window.exists ? window.screenshot() : app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
