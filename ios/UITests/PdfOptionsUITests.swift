import XCTest

final class PdfOptionsUITests: XCTestCase {
    func testOptionsReachSavedFileAndPreview() {
        let app = XCUIApplication()
        app.launchArguments = ["--pdf-options-ui-test"]
        app.launch()
        let open = app.buttons["导出 PDF"]
        XCTAssertTrue(open.waitForExistence(timeout: 20))
        open.tap()
        selectPaper("A5", app: app)
        setSwitch("保留背景色", enabled: true, app: app)
        setSwitch("自动打开", enabled: true, app: app)
        app.buttons["导出"].firstMatch.tap()
        let info = app.staticTexts["pdf-generated-info"]
        XCTAssertTrue(info.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertEqual(info.label, "PDF-FILE: width=420, warm=true")
        app.buttons["pdf-test-save"].tap()
        let done = app.buttons.matching(NSPredicate(format: "label IN %@", ["Done", "完成"])).firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 10), app.debugDescription)
        done.tap()
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        XCTAssertEqual(app.switches["保留背景色"].firstMatch.value as? String, "1")
        XCTAssertEqual(app.switches["自动打开"].firstMatch.value as? String, "1")
        selectPaper("A4", app: app)
        setSwitch("保留背景色", enabled: false, app: app)
        setSwitch("自动打开", enabled: false, app: app)
        app.buttons["导出"].firstMatch.tap()
        XCTAssertTrue(info.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertEqual(info.label, "PDF-FILE: width=595, warm=false")
        app.buttons["pdf-test-save"].tap()
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        XCTAssertFalse(done.waitForExistence(timeout: 3), app.debugDescription)
    }

    private func selectPaper(_ title: String, app: XCUIApplication) {
        let item = app.staticTexts[title].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 10))
        item.tap()
    }

    private func setSwitch(_ title: String, enabled: Bool, app: XCUIApplication) {
        let toggle = app.switches[title].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), app.debugDescription)
        if !toggle.isHittable { app.swipeUp() }
        if toggle.value as? String != (enabled ? "1" : "0") { toggle.tap() }
        XCTAssertEqual(toggle.value as? String, enabled ? "1" : "0", app.debugDescription)
    }
}
