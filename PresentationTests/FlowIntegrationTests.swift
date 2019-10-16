//
//  RandomTests.swift
//  PresentationTests
//
//  Created by Martin on 2019-10-16.
//  Copyright © 2019 iZettle. All rights reserved.
//

import XCTest
import Flow
@testable import Presentation

private struct TestPresentable: Presentable {
    func materialize() -> (UIViewController, Future<Int>) {
        return (UIViewController(), Future(1).delay(by: 10000))
    }
}

class FlowIntegrationTests: XCTestCase {

    let bag = DisposeBag()

    override func tearDown() {
        bag.dispose()
        super.tearDown()
    }

    func testOverrideWithSucessFuture() {
        let window = UIWindow()
        window.makeKeyAndVisible()
        let waitTime: TimeInterval = 2
        let presenter = UIViewController()
        window.rootViewController = presenter

        let presented = Presentation(
            TestPresentable(),
            style: .modal
        )

        let e = expectation(description: "Delayed by 2 sec")

        bag += presenter.present(presented)
            .succeed(with: 2, after: waitTime)
            .map { String($0) }
            .onValue {
                XCTAssertEqual($0, "2")
                e.fulfill()
        }

        waitForExpectations(timeout: waitTime + 0.1, handler: { (err) in
            if let err = err {
                XCTFail(err.localizedDescription)
            }
        })
    }

}
