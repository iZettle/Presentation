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
            showDismissablePresentation(style: style, option: "Default")

            let isSideBySideSplitView = app.launchArguments.contains("UseSplitViewContainer") &&
                UIDevice.current.userInterfaceIdiom == .pad
            if !isSideBySideSplitView {
                pressBack()
                XCTAssertTrue(initialScreenVisible)
            }

            showDismissablePresentation(style: style, option: "Default")
            // completing the presentation doesn't dismiss the pushed vc automatically, we need to pass .autoPop for that
            pressDismiss()
            pressDismiss()
            pressBack()
            XCTAssertTrue(initialScreenVisible)

            showDismissablePresentation(style: style, option: "Auto Pop Self And Successors (for navigation vc)")
            pressDismiss()
            XCTAssertTrue(initialScreenVisible)

            // no special behaviour for navigation presentation
            showDismissablePresentation(style: style, option: "Fail On Block (for modal/popover vc)")
            pressBack()
            XCTAssertTrue(initialScreenVisible)

            showDismissablePresentation(style: style, option: "Unanimated")
            pressBack()
            XCTAssertTrue(initialScreenVisible)
        }
    }

    func testPopoverPresentationStyle() {
        let style = "popover"
        let cancel = app.navigationBars["UIView"].buttons["Cancel"]

        verifyForAllContainerConfigurations {
            showDismissablePresentation(style: style, option: "Default")
            XCTAssertFalse(cancel.exists)
            pressDismiss()
            XCTAssertTrue(initialScreenVisible)

            showDismissablePresentation(style: style, option: "Embed In Navigation Controller")
            XCTAssertFalse(cancel.exists)
            pressDismiss()
            XCTAssertTrue(initialScreenVisible)

            showDismissablePresentation(style: style, option: "Unanimated")
            XCTAssertFalse(cancel.exists)
            pressDismiss()
            XCTAssertTrue(initialScreenVisible)

            showDismissablePresentation(style: style, option: "Fail On Block (for modal/popover vc)")
            XCTAssertTrue(initialScreenVisible)
        }
    }

    func testModalPresentationStyle() {
        let style = "modal"
        let cancel = app.navigationBars["UIView"].buttons["Cancel"]

        verifyForAllContainerConfigurations {
            showDismissablePresentation(style: style, option: "Embed In Navigation Controller")
            cancel.tap()
            XCTAssertTrue(initialScreenVisible)

            showDismissablePresentation(style: style, option: "Embed In Navigation Controller")
            pressDismiss()
            XCTAssertTrue(initialScreenVisible)

            showDismissablePresentation(style: style, option: "Default")
            cancel.tap()
            XCTAssertTrue(initialScreenVisible)

            showDismissablePresentation(style: style, option: "Fail On Block (for modal/popover vc)")
            XCTAssertTrue(initialScreenVisible)

            showDismissablePresentation(style: style, option: "Unanimated")
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
            showDismissablePresentation(style: style, option: "Fail On Block (for modal/popover vc)")
            XCTAssertEqual(okButton.exists, false)

            showDismissablePresentation(style: style, option: "Default")
            okButton.tap()
            XCTAssertTrue(initialScreenVisible)
        }
    }

    func testEmbeddedPresentationStyle() {
        let style = "embed"

        verifyForAllContainerConfigurations {
            showDismissablePresentation(style: style, option: "Default")
            XCTAssertTrue(initialScreenVisible)

            pressDismiss()
            XCTAssertTrue(initialScreenVisible)
        }
    }

    func testInvisiblePresentationStyle() {
        let style = "invisible"

        verifyForAllContainerConfigurations {
            showDismissablePresentation(style: style, option: "Default")
            XCTAssertTrue(initialScreenVisible)
        }
    }

    func testSwipeDownToDismissModal() {
        if #available(iOS 13.0, *) {
            let style = "modal"

            verifyForAllContainerConfigurations {
                showDismissablePresentation(style: style, option: "Show alert on swipe down to dismiss")
                app.swipeDown()
                pressAlertOK()
                pressDismiss()

                showDismissablePresentation(style: style, option: "Embed in navigation and swipe down to dismiss")
                app.swipeDown()
                pressAlertOK()
                pressDismiss()

                // Drag modal down and dismiss it
                showDismissablePresentation(style: style, option: "Default")
                let dismissButton = app.buttons["Tap To Dismiss"]
                let navBar = app.navigationBars["UIView"]
                navBar.press(forDuration: 0.5, thenDragTo: dismissButton)
                XCTAssertFalse(dismissButton.exists)

                // When in navigation stack with more than one view controller, dragging down dismisses a view only if that option has been passed
                showDismissablePresentation(style: style, option: "Allow swipe to dismiss always")
                let backButton = navBar.buttons["Back"]
                XCTAssertTrue(backButton.waitForExistence(timeout: 1))
                navBar.press(forDuration: 0.5, thenDragTo: dismissButton)
                XCTAssertFalse(dismissButton.exists)
            }
        }
    }

    // Issue: https://github.com/iZettle/Presentation/issues/36
    func disabled_testNavigationBarVisibilityPreference() {
        app.launch()
        showDismissablePresentation(style: "default", option: "NavigationBar visibility preference")
        let navBar = app.navigationBars["UIView"]
        let nextButton = app.buttons["Next"]
        let backButton = navBar.buttons["Back"]

        XCTAssertTrue(navBar.exists)

        nextButton.tap()
        XCTAssertFalse(navBar.exists)

        nextButton.tap()
        XCTAssertTrue(navBar.exists)

        backButton.tap()
        XCTAssertFalse(navBar.exists)

        nextButton.tap()
        XCTAssertTrue(navBar.exists)

        nextButton.tap()
        XCTAssertFalse(navBar.exists)

        nextButton.tap()
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

    func showDismissablePresentation(style: String, option: String, file: StaticString = #file, line: UInt = #line) {
        let tablesQuery = app.tables

        XCTAssertTrue(app.navigationBars["Presentation Styles"].exists, file: file, line: line)
        tablesQuery.cells.staticTexts[style].tap()
        XCTAssertTrue(app.navigationBars["Presentation Options"].exists, file: file, line: line)
        tablesQuery.cells.staticTexts[option].tap()
        let dismiss = app.buttons["Tap To Dismiss"]
        XCTAssert(dismiss.waitForExistence(timeout: 1.0), file: file, line: line)
    }

    func pressAlertOK(file: StaticString = #file, line: UInt = #line) {
        let okButton = app.alerts.buttons["OK"]
        XCTAssertTrue(okButton.waitForExistence(timeout: 1), file: file, line: line)
        XCTAssertTrue(okButton.exists, file: file, line: line)
        okButton.tap()
    }

    func pressBack(file: StaticString = #file, line: UInt = #line) {
        let back = app.navigationBars["UIView"].buttons.firstMatch
        XCTAssert(back.waitForExistence(timeout: 1.0), file: file, line: line)
        back.tap()
    }
    
    func pressDismiss(file: StaticString = #file, line: UInt = #line) {
        let dismiss = app.buttons["Tap To Dismiss"]
        XCTAssert(dismiss.waitForExistence(timeout: 1.0), file: file, line: line)
        dismiss.tap()
    }

    var initialScreenVisible: Bool {
        return app.navigationBars["Presentation Styles"].exists
    }
}
