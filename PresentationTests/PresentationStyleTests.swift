//
//  Copyright © 2021 PayPal Inc. All rights reserved.
//

import XCTest
import Flow
@testable import Presentation

class PresentationStyleTests: XCTestCase {

    // MARK: - Dismissal Setup

    func testModalPresentationDismissalSetup_forNavigationController_rootWithDismiss() {
        let viewController = UIViewController()
        viewController.dismissBarItem = .dummy
        let navigationController = UINavigationController(rootViewController: viewController)

        _ = PresentationStyle.modalPresentationDismissalSetup(for: navigationController, options: .defaults)

        waitForNextrunLoop()

        XCTAssertNil(navigationController.navigationItem.leftBarButtonItems)
        XCTAssertEqual(viewController.navigationItem.leftBarButtonItems?.count, 1)
    }

    func testModalPresentationDismissalSetup_forNavigationController_withDismiss() {
        let viewController = UIViewController()
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.dismissBarItem = .dummy

        _ = PresentationStyle.modalPresentationDismissalSetup(for: navigationController, options: .defaults)

        waitForNextrunLoop()

        XCTAssertNil(navigationController.navigationItem.leftBarButtonItems)
        XCTAssertEqual(viewController.navigationItem.leftBarButtonItems?.count, 1)
    }

    func testModalPresentationDismissalSetup_forVCInNavController_withDismiss() {
        let viewController = UIViewController()
        viewController.dismissBarItem = .dummy
        let navigationController = UINavigationController(rootViewController: viewController)

        _ = PresentationStyle.modalPresentationDismissalSetup(for: viewController, options: .defaults)

        waitForNextrunLoop()

        XCTAssertNil(navigationController.navigationItem.leftBarButtonItems)
        XCTAssertEqual(viewController.navigationItem.leftBarButtonItems?.count, 1)
    }

    func testModalPresentationDismissalSetup_forVCInNavController_withoutDismiss() {
        let viewController = UIViewController()
        let navigationController = UINavigationController(rootViewController: viewController)

        _ = PresentationStyle.modalPresentationDismissalSetup(for: viewController, options: .defaults)

        waitForNextrunLoop()

        XCTAssertNil(navigationController.navigationItem.leftBarButtonItems)
        XCTAssertNil(viewController.navigationItem.leftBarButtonItems)
    }

    private func waitForNextrunLoop() {
        let nextRunLoop = expectation(description: "nextRunLoop")
        Future().delay(by: 0).onValue {
            nextRunLoop.fulfill()
        }
        wait(for: [nextRunLoop], timeout: 0.1)
    }
}

extension UIBarButtonItem {
    fileprivate static var dummy: UIBarButtonItem {
        UIBarButtonItem(title: "Close", style: .plain, target: nil, action: nil)
    }
}
