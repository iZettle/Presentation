//
//  MasterDetailSelectionTests.swift
//  PresentationTests
//
//  Created by Måns Bernhardt on 2017-07-31.
//  Copyright © 2017 PayPal Inc. All rights reserved.
//

import XCTest
import Flow
import Presentation

class MasterDetailSelectionTests: XCTestCase {
    func testPresentDetailsExpanded() {
        let items = ReadWriteSignal([1, 2, 3])
        let isCollapsed = ReadWriteSignal<Bool?>(false)
        var presentedIndex: Int?

        var presentCount = 0
        let masterDetail = MasterDetailSelection(elements: items.readOnly(), isSame: ==, isCollapsed: isCollapsed.readOnly())

        let bag = DisposeBag()
        bag += masterDetail.presentDetail { indexAndElement in
            presentedIndex = indexAndElement?.index
            presentCount += 1
            return Disposer {
                presentedIndex = nil
            }
        }  // present

        XCTAssertEqual(presentedIndex, 0)
        masterDetail.select(index: 1)  // present
        XCTAssertEqual(presentedIndex, 1)
        items.value = []  // present (nil)
        XCTAssertEqual(presentedIndex, nil)
        items.value = [4, 5, 6]  // present
        XCTAssertEqual(presentedIndex, 0)

        masterDetail.deselect() // present
        XCTAssertEqual(presentedIndex, nil)

        masterDetail.select(index: 2) // present
        XCTAssertEqual(presentedIndex, 2)
        items.value = [4, 5]  // present
        XCTAssertEqual(presentedIndex, 1)

        XCTAssertEqual(presentCount, 7)
    }

    func testPresentDetailsCollpased() {
        let items = ReadWriteSignal([1, 2, 3])
        let isCollapsed = ReadWriteSignal<Bool?>(true)
        var presentedIndex: Int?

        var presentCount = 0
        let masterDetail = MasterDetailSelection(elements: items.readOnly(), isSame: ==, isCollapsed: isCollapsed.readOnly())

        let bag = DisposeBag()
        bag += masterDetail.presentDetail { indexAndElement in
            presentedIndex = indexAndElement?.index
            if indexAndElement != nil {
                presentCount += 1
            }
            return Disposer { presentedIndex = nil }
        }

        XCTAssertEqual(presentedIndex, nil)
        masterDetail.select(index: 1) // present
        XCTAssertEqual(presentedIndex, 1)
        items.value = []
        XCTAssertEqual(presentedIndex, nil)
        items.value = [4, 5, 6]
        XCTAssertEqual(presentedIndex, nil)
        masterDetail.select(index: 2)  // present
        XCTAssertEqual(presentedIndex, 2)
        items.value = [4, 5]
        XCTAssertEqual(presentedIndex, nil)

        XCTAssertEqual(presentCount, 2)
    }

    func testExpandedToCollapsed() {
        let items = ReadWriteSignal([1, 2, 3])
        let isCollapsed = ReadWriteSignal<Bool?>(true)
        var presentedIndex: Int?

        var presentCount = 0
        let masterDetail = MasterDetailSelection(elements: items.readOnly(), isSame: ==, isCollapsed: isCollapsed.readOnly())

        let bag = DisposeBag()
        bag += masterDetail.presentDetail { indexAndElement in
            presentedIndex = indexAndElement?.index
            if indexAndElement != nil {
                presentCount += 1
            }
            return Disposer { presentedIndex = nil }
        }

        XCTAssertEqual(presentedIndex, nil)
        isCollapsed.value = false // present
        XCTAssertEqual(presentedIndex, 0)
        masterDetail.select(index: 1) // present
        XCTAssertEqual(presentedIndex, 1)
        isCollapsed.value = true
        XCTAssertEqual(presentedIndex, 1)
        masterDetail.deselect()
        XCTAssertEqual(presentedIndex, nil)
        masterDetail.select(index: 2) // present
        XCTAssertEqual(presentedIndex, 2)
        isCollapsed.value = false
        XCTAssertEqual(presentedIndex, 2)

        XCTAssertEqual(presentCount, 3)
    }

    func testExpandedStepBetween() {
        let items = ReadWriteSignal([1, 2, 3])
        let isCollapsed = ReadWriteSignal<Bool?>(false)
        var presentedIndex: Int?

        var presentCount = 0
        let masterDetail = MasterDetailSelection(elements: items.readOnly(), isSame: ==, isCollapsed: isCollapsed.readOnly())

        let bag = DisposeBag()
        bag += masterDetail.presentDetail { indexAndElement in
            presentedIndex = indexAndElement?.index
            presentCount += 1
            return Disposer {
                presentedIndex = nil
            }
        }  // present

        XCTAssertEqual(presentedIndex, 0)
        masterDetail.select(index: 1)  // present
        masterDetail.select(index: 1)  // no present
        XCTAssertEqual(presentedIndex, 1)
        masterDetail.select(index: 2)  // present
        masterDetail.select(index: 2)  // no present
        XCTAssertEqual(presentedIndex, 2)

        XCTAssertEqual(presentCount, 3)
    }

    func testCollapsedStepBetween() {
        let items = ReadWriteSignal([1, 2, 3])
        let isCollapsed = ReadWriteSignal<Bool?>(true)
        var presentedIndex: Int?

        var presentCount = 0
        let masterDetail = MasterDetailSelection(elements: items.readOnly(), isSame: ==, isCollapsed: isCollapsed.readOnly())

        let bag = DisposeBag()
        bag += masterDetail.presentDetail { indexAndElement in
            presentedIndex = indexAndElement?.index
            if indexAndElement != nil {
                presentCount += 1
            }
            return Disposer { presentedIndex = nil }
        }

        XCTAssertEqual(presentedIndex, nil)
        masterDetail.select(index: 1)  // present
        masterDetail.select(index: 1)  // no present
        XCTAssertEqual(presentedIndex, 1)
        masterDetail.select(index: 2)  // present
        masterDetail.select(index: 2)  // no present
        XCTAssertEqual(presentedIndex, 2)

        masterDetail.deselect()
        masterDetail.select(index: 1)  // present
        masterDetail.select(index: 1)  // no present
        XCTAssertEqual(presentedIndex, 1)

        XCTAssertEqual(presentCount, 3)
    }
}
