import XCTest

final class PdfOptionsUITests: XCTestCase {
    func testSelectedOptionsReachExporterAfterDismissal() {
        let app = XCUIApplication()
        app.launchArguments = ["--pdf-options-ui-test"]
        app.launch()
        let open = app.buttons["导出 PDF"]
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        open.tap()
        let paper = app.staticTexts["A5"].firstMatch
        XCTAssertTrue(paper.waitForExistence(timeout: 10))
        paper.tap()
        for title in ["保留背景色", "自动打开"] {
            let toggle = app.switches[title].firstMatch
            XCTAssertTrue(toggle.waitForExistence(timeout: 5), app.debugDescription)
            if !toggle.isHittable { app.swipeUp() }
            toggle.tap()
            XCTAssertEqual(toggle.value as? String, "1", app.debugDescription)
        }
        app.buttons["导出"].firstMatch.tap()
        let selected = app.staticTexts["PDF-OPTIONS: paper=a5, background=true, open=true"]
        XCTAssertTrue(selected.waitForExistence(timeout: 10), app.debugDescription)
    }
}
