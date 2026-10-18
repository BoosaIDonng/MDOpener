import XCTest

final class FolderReadingUITests: XCTestCase {
    func testSelectSkipReadNextAndRestore() {
        let app = XCUIApplication()
        app.launchArguments = ["--folder-reading-ui-test"]
        app.launch()
        let library = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "3 篇文档")).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: 15), app.debugDescription)
        library.tap()
        document("1.md", in: app).tap()
        XCTAssertTrue(app.navigationBars["1.md"].waitForExistence(timeout: 10), app.debugDescription)
        let next = app.buttons["阅读下一篇"]
        XCTAssertFalse(next.exists)
        scrollToEnd(app)
        XCTAssertTrue(next.waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["稍后"].tap()
        app.webViews.firstMatch.swipeDown()
        app.webViews.firstMatch.swipeUp()
        XCTAssertFalse(next.exists, "dismissed prompt repeated")

        app.buttons["文件夹文档"].tap()
        document("2.md", in: app).tap()
        XCTAssertTrue(app.navigationBars["2.md"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertFalse(next.exists)
        scrollToEnd(app)
        XCTAssertTrue(next.waitForExistence(timeout: 5), app.debugDescription)
        next.tap()
        XCTAssertTrue(app.navigationBars["10.md"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertFalse(next.waitForExistence(timeout: 2), "last document offered another document")

        app.buttons["文件夹文档"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("10")
        XCTAssertTrue(document("10.md", in: app).exists, app.debugDescription)
        XCTAssertFalse(document("1.md", in: app, wait: false).exists)
        document("10.md", in: app).tap()
        XCTAssertTrue(app.navigationBars["10.md"].waitForExistence(timeout: 10))
        app.buttons["返回"].tap()
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(library.waitForExistence(timeout: 15), "folder bookmark did not restore")
        library.tap()
        document("2.md", in: app).tap()
        XCTAssertTrue(app.navigationBars["2.md"].waitForExistence(timeout: 10))
    }

    private func document(_ name: String, in app: XCUIApplication, wait: Bool = true) -> XCUIElement {
        let item = app.buttons.matching(NSPredicate(format: "label == %@ OR label BEGINSWITH %@", name, name + ",")).firstMatch
        if wait { XCTAssertTrue(item.waitForExistence(timeout: 10), app.debugDescription) }
        return item
    }

    private func scrollToEnd(_ app: XCUIApplication) {
        let web = app.webViews.firstMatch
        XCTAssertTrue(web.waitForExistence(timeout: 10))
        for _ in 0..<20 {
            if app.buttons["阅读下一篇"].exists { return }
            web.swipeUp()
        }
    }
}
