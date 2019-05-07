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

    func showDismissablePresentation(style: String, option: String) {
        let tablesQuery = app.tables

        XCTAssertTrue(app.navigationBars["Presentation Styles"].exists)
        tablesQuery.cells.staticTexts[style].tap()
        XCTAssertTrue(app.navigationBars["Presentation Options"].exists)
        tablesQuery.cells.staticTexts[option].tap()
    }

    func pressBack() {
        let back = app.navigationBars["UIView"].buttons.firstMatch
        back.tap()
    }

    func pressDismiss() {
        let dismiss = app.buttons["Tap To Dismiss"]
        dismiss.tap()
    }

    var initialScreenVisible: Bool {
        return app.navigationBars["Presentation Styles"].exists
    }
}
