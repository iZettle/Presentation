//
//  ExampleUITests.swift
//  ExampleUITests
//
//  Created by Nataliya Patsovska on 2018-06-13.
//  Copyright © 2018 iZettle. All rights reserved.
//

import XCTest
@testable import Example

class ExampleUITests: XCTestCase {
    var app: XCUIApplication!
    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        continueAfterFailure = false
    }

    func testNavigationPresentationStyle() {
        let style = "default"

        verifyForAllContainerConfigurations {
            chooseStyleAndOption(style: style, option: "Default")

            let isSideBySideSplitView = app.launchArguments.contains("UseSplitViewContainer") &&
                UIDevice.current.userInterfaceIdiom == .pad
            if !isSideBySideSplitView {
                pressBack()
                XCTAssertTrue(initialScreenVisible)
            }

            chooseStyleAndOption(style: style, option: "Default")
            // completing the presentation doesn't dismiss the pushed vc automatically, we need to pass .autoPop for that
            pressDismiss()
            pressDismiss()
            pressBack()
            XCTAssertTrue(initialScreenVisible)

            chooseStyleAndOption(style: style, option: "Auto Pop Self And Successors (for navigation vc)")
            pressDismiss()
            XCTAssertTrue(initialScreenVisible)

            // no special behaviour for navigation presentation
            chooseStyleAndOption(style: style, option: "Fail On Block (for modal/popover vc)")
            pressBack()
            XCTAssertTrue(initialScreenVisible)

            chooseStyleAndOption(style: style, option: "Unanimated")
            pressBack()
            XCTAssertTrue(initialScreenVisible)
        }
    }

    func testPopoverPresentationStyle() {
        let style = "popover"
        let cancel = app.navigationBars["UIView"].buttons["Cancel"]

        verifyForAllContainerConfigurations {
            chooseStyleAndOption(style: style, option: "Default")
            XCTAssertFalse(cancel.exists)
            pressDismiss()
            XCTAssertTrue(initialScreenVisible)

            chooseStyleAndOption(style: style, option: "Embed In Navigation Controller")
            XCTAssertFalse(cancel.exists)
            pressDismiss()
            XCTAssertTrue(initialScreenVisible)

            chooseStyleAndOption(style: style, option: "Unanimated")
            XCTAssertFalse(cancel.exists)
            pressDismiss()
            XCTAssertTrue(initialScreenVisible)

            chooseStyleAndOption(style: style, option: "Fail On Block (for modal/popover vc)")
            XCTAssertTrue(initialScreenVisible)
        }
    }

    func testModalPresentationStyle() {
        let style = "modal"
        let cancel = app.navigationBars["UIView"].buttons["Cancel"]

        verifyForAllContainerConfigurations {
            chooseStyleAndOption(style: style, option: "Embed In Navigation Controller")
            cancel.waitForExistenceAndTap()
            XCTAssertTrue(initialScreenVisible)

            chooseStyleAndOption(style: style, option: "Embed In Navigation Controller")
            pressDismiss()
            XCTAssertTrue(initialScreenVisible)

            chooseStyleAndOption(style: style, option: "Default")
            cancel.waitForExistenceAndTap()
            XCTAssertTrue(initialScreenVisible)

            chooseStyleAndOption(style: style, option: "Fail On Block (for modal/popover vc)")
            XCTAssertTrue(initialScreenVisible)

            chooseStyleAndOption(style: style, option: "Unanimated")
            XCTAssertEqual(cancel.exists, false)
            pressDismiss()
            XCTAssertTrue(initialScreenVisible)

            XCTAssertTrue(initialScreenVisible)
        }
    }

    func testSheetPresentationStyle() {
        let style = "sheet"
        let okButton = app.sheets.buttons["OK"]

        verifyForAllContainerConfigurations {
            chooseStyleAndOption(style: style, option: "Fail On Block (for modal/popover vc)")
            XCTAssertEqual(okButton.exists, false)

            chooseStyleAndOption(style: style, option: "Default")
            okButton.waitForExistenceAndTap()
            XCTAssertTrue(initialScreenVisible)
        }
    }

    func testEmbeddedPresentationStyle() {
        let style = "embed"

        verifyForAllContainerConfigurations {
            chooseStyleAndOption(style: style, option: "Default")
            XCTAssertTrue(initialScreenVisible)

            pressDismiss()
            XCTAssertTrue(initialScreenVisible)
        }
    }

    func testInvisiblePresentationStyle() {
        let style = "invisible"

        verifyForAllContainerConfigurations {
            chooseStyleAndOption(style: style, option: "Default")
            XCTAssertTrue(initialScreenVisible)
        }
    }

    func testSwipeDownToDismissModal() {
        if #available(iOS 13.0, *) {
            let style = "modal"
            let dismissButton = app.buttons["Tap To Dismiss"]
            let navBar = app.navigationBars["UIView"]

            func swipeDown(afterExistenseOf requiredElement: XCUIElement) {
                XCTAssertTrue(requiredElement.waitForExistence(timeout: 1.0))
                app.swipeDown()
            }

            func dragDownFromNavigationBar(to toElement: XCUIElement, afterExistenseOf requiredElement: XCUIElement) {
                XCTAssertTrue(requiredElement.waitForExistence(timeout: 1.0))
                navBar.press(forDuration: 0.5, thenDragTo: toElement)
            }

            verifyForAllContainerConfigurations {
                chooseStyleAndOption(style: style, option: "Show alert on swipe down to dismiss")
                swipeDown(afterExistenseOf: dismissButton)
                pressAlertOK()
                dismissButton.tap()

                chooseStyleAndOption(style: style, option: "Embed in navigation and swipe down to dismiss")
                swipeDown(afterExistenseOf: dismissButton)
                pressAlertOK()
                dismissButton.tap()

                // Drag modal down and dismiss it
                chooseStyleAndOption(style: style, option: "Default")
                dragDownFromNavigationBar(to: dismissButton, afterExistenseOf: dismissButton)
                XCTAssertFalse(dismissButton.exists)

                // When in navigation stack with more than one view controller, dragging down dismisses a view only if that option has been passed
                chooseStyleAndOption(style: style, option: "Allow swipe to dismiss always")
                dragDownFromNavigationBar(to: dismissButton, afterExistenseOf: navBar.buttons["Back"])
                XCTAssertFalse(dismissButton.exists)
            }
        }
    }

    func testNavigationBarVisibilityPreference() {
        app.launch()
        chooseStyleAndOption(style: "default", option: "NavigationBar visibility preference")
        let navBar = app.navigationBars["UIView"]
        let nextButton = app.buttons["Next"]
        let backButton = navBar.buttons["Back"]

        XCTAssertTrue(navBar.exists)

        nextButton.waitForExistenceAndTap()
        XCTAssertFalse(navBar.exists)

        nextButton.waitForExistenceAndTap()
        XCTAssertTrue(navBar.exists)

        backButton.waitForExistenceAndTap()
        XCTAssertFalse(navBar.exists)

        nextButton.waitForExistenceAndTap()
        XCTAssertTrue(navBar.exists)

        nextButton.waitForExistenceAndTap()
        XCTAssertFalse(navBar.exists)

        nextButton.waitForExistenceAndTap()
        XCTAssertFalse(navBar.exists)

        app.terminate()
    }
    
    // MARK: - Helpers
    func verifyForAllContainerConfigurations(_ verify: () -> ()) {
        ["UseNavigationContainer", "UseSplitViewContainer"].forEach { containerTypeOption in
            let name = "Test with \(containerTypeOption) configurationn"
            XCTContext.runActivity(named: name) { _ in
                app.launchArguments = [containerTypeOption]
                app.launch()
                verify()
                app.terminate()
            }
        }
    }

    func chooseStyleAndOption(style: String, option: String, file: StaticString = #file, line: UInt = #line) {
        let tablesQuery = app.tables

        XCTAssertTrue(app.navigationBars["Presentation Styles"].exists, file: file, line: line)
        tablesQuery.cells.staticTexts[style].tap()
        XCTAssertTrue(app.navigationBars["Presentation Options"].exists, file: file, line: line)
        tablesQuery.cells.staticTexts[option].tap()
    }

    func pressAlertOK(file: StaticString = #file, line: UInt = #line) {
        let okButton = app.alerts.buttons["OK"]
        okButton.waitForExistenceAndTap(file: file, line: line)
    }

    func pressBack(file: StaticString = #file, line: UInt = #line) {
        let back = app.navigationBars["UIView"].buttons.firstMatch
        back.waitForExistenceAndTap(file: file, line: line)
    }
    
    func pressDismiss(file: StaticString = #file, line: UInt = #line) {
        let dismiss = app.buttons["Tap To Dismiss"]
        dismiss.waitForExistenceAndTap(file: file, line: line)
    }

    var initialScreenVisible: Bool {
        return app.navigationBars["Presentation Styles"].exists
    }
}

extension XCUIElement {
    func waitForExistenceAndTap(file: StaticString = #file, line: UInt = #line) {
        XCTAssert(self.waitForExistence(timeout: 1.0), file: file, line: line)
        self.tap()
    }
}
