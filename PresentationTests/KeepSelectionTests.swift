//
//  KeepSelectionTests.swift
//  Presentation
//
//  Created by Måns Bernhardt on 2017-08-04.
//  Copyright © 2017 PayPal Inc. All rights reserved.
//

import XCTest
import Presentation
import Flow

class KeepSelectionTests: XCTestCase {
    func testExample() {
        let items = ReadWriteSignal([1, 2, 3])
        let selection = KeepSelection(elements: items.readOnly(), isSame: ==)
        let bag = DisposeBag()

        var index: Int?
        var cnt = 0
        bag += selection.atOnce().onValue {
            cnt += 1
            index = $0?.index
        } // inc

        XCTAssertEqual(index, 0)
        selection.select(index: 1) // inc
        XCTAssertEqual(index, 1)
        items.value = [1, 3] // inc
        XCTAssertEqual(index, 1)
        items.value = [1, 2, 3] // inc
        XCTAssertEqual(index, 2)
        items.value = [1, 2] // inc
        items.value = [1, 2] // inc
        XCTAssertEqual(index, 1)
        items.value = [] // inc
        XCTAssertEqual(index, nil)
        items.value = [1, 2, 3] // inc
        items.value = [1, 2, 3] // inc
        XCTAssertEqual(index, 0)

        XCTAssertEqual(cnt, 9)

    }

}
