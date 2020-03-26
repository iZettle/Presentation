//
//  MasterDetailSelection.swift
//  Presentation
//
//  Created by Måns Bernhardt on 2017-08-01.
//  Copyright © 2017 iZettle. All rights reserved.
//

import Foundation
import Flow
import UIKit

/// Helper that listens on elements and isCollapsed changes to maintain a detail selection.
public final class MasterDetailSelection<Elements: BidirectionalCollection>: SignalProvider {
    public typealias Index = Elements.Index
    public typealias Element = Elements.Iterator.Element
    public typealias IndexAndElement = (index: Index, element: Element)

    private var current: IndexAndElement?
    private let callbacker = Callbacker<IndexAndElement?>()
    private let bag = DisposeBag()
    fileprivate let keepSelection: KeepSelection<Elements>
    private var isSelecting = false
    fileprivate let isCollapsed: ReadSignal<Bool?>

    @available(*, deprecated, message: "pass isCollapsed as a ReadSignal<Bool?> instead")
    public convenience init(elements: ReadSignal<Elements>, isSame: @escaping (Element, Element) -> Bool, needsUpdate: @escaping (Element, Element) -> Bool = { _, _ in false }, isCollapsed: ReadSignal<Bool>) {
        self.init(elements: elements, isSame: isSame, needsUpdate: needsUpdate, isCollapsed: isCollapsed.map { value -> Bool? in return value })
    }

    /// Creates a new instance using changes in `elements` and `isCollapsed` to maintain the selected detail index (provided signal).
    /// - Parameters:
    ///   - isSame: Is it the same row (same identity)
    ///   - needsUpdate: For the same row, does the row have updates that requires presenting new details (refresh details)
    ///   - isCollapsed: Whether or not details are displayed.
    public init(elements: ReadSignal<Elements>, isSame: @escaping (Element, Element) -> Bool, needsUpdate: @escaping (Element, Element) -> Bool = { _, _ in false }, isCollapsed: ReadSignal<Bool?>) {
        keepSelection = KeepSelection(elements: elements, isSame: isSame)
        self.isCollapsed = isCollapsed

        bag += isCollapsed.atOnce().with(weak: self).onValueDisposePrevious { isCollapsed, `self` in
            guard let isCollapsed = isCollapsed else { return NilDisposer() }
            return self.keepSelection.atOnce().enumerate().with(weak: self).onValue { (eventCount, indexAndElement, `self`) in
                let indexWasUpdated = eventCount > 0 // if eventCount is 0, it was just the atOnce value
                let index = indexAndElement?.index
                let elementDidUpdate = indexAndElement.flatMap { i in self.current.map {
                    !isSame($0.element, i.element)
                }} ?? true

                let prev = self.current
                let prevIndex = prev?.index

                switch (isCollapsed, index, indexWasUpdated) {
                case (_, _, false) where index == self.current?.index:
                    return
                case (false, _, _):
                    self.current = indexAndElement
                case (true, nil, _):
                    self.current = nil
                case (true, _?, true) where elementDidUpdate:
                    self.current = nil
                case (true, _?, _):
                    break
                }

                let current = self.current
                self.callbacker.callAll(with: current)

                var elementContentDidChange: Bool {
                    if indexWasUpdated && !elementDidUpdate, let lhs = prev?.element, let rhs = current?.element {
                        return needsUpdate(lhs, rhs)
                    } else {
                        return false
                    }
                }

                guard self.isSelecting || (indexWasUpdated && prevIndex != nil && current == nil) || ((!isCollapsed || current != nil) && (elementDidUpdate || elementContentDidChange)) else { return }

                self.presentDetail.call(current)
            }
        }
    }

    /// Returns current elements.
    public var elements: Elements {
        return keepSelection.elements
    }

    /// Returns a signal with the current elements.
    public var elementsSignal: ReadSignal<Elements> {
        return keepSelection.elementsSignal
    }

    /// Returns a signal the will signal when the selected index and element is updated.
    public var providedSignal: ReadSignal<IndexAndElement?> {
        return ReadSignal(getValue: { self.current }, callbacker: callbacker)
    }

    /// Update the selected index.
    public func select(index: Index) {
        guard index != current?.index else { return }

        current = (index, keepSelection.elements[index]) // Can we remove the list and the one above since keepSelection will update?
        isSelecting = true
        keepSelection.select(index: index)
        isSelecting = false
    }

    /// Deselect the current selection if any.
    public func deselect() {
        guard current != nil else { return }
        current = nil
        presentDetail.call(nil)
        callbacker.callAll(with: nil)
    }

    /// Delegate the will be called when details should be presented for an index and element.
    public lazy var presentDetail: Delegate<IndexAndElement?, ()> = {
        return Delegate { [weak self] onSet in
            guard let `self` = self else {
                return NilDisposer()
            }
            onSet((self.isCollapsed.value ?? true) ? nil: self.current)
            return NilDisposer()
        }
    }()
}

public extension MasterDetailSelection {
    /// Setups a `presentation` callback that will be called when details should be presented.
    /// Before `presentation` is called any disposable returned by a previous call to `presentation` will be disposed.
    func presentDetail(presentation: @escaping (IndexAndElement?) -> Disposable) -> Disposable {
        let detailBag = DisposeBag()
        let bag = DisposeBag(detailBag)

        bag += self.presentDetail.set { indexAndElement in
            detailBag.dispose()
            detailBag += presentation(indexAndElement)
        }

        return bag
    }

    /// Setups a `presentation` callback that will be called when details should be presented and where the returned presentation will be presented on `vc` .
    /// Before `presentation` is called any presentation returned by a previous call to `presentation` will be dismissed.
    func presentDetail(on vc: UIViewController, presentation: @escaping (IndexAndElement?) -> DisposablePresentation?) -> Disposable {
        let detailBag = DisposeBag()
        let bag = DisposeBag(detailBag)
        var immediate = true

        bag += self.presentDetail.set { indexAndElement in
            guard let isCollapsed = self.isCollapsed.value else { return }
            guard !isCollapsed || indexAndElement != nil else {
                detailBag.dispose()
                return
            }

            guard var presentation = presentation(indexAndElement) else { return }

            presentation.options.formUnion(.autoPopSelfAndSuccessors)

            immediate = true
            let presentDisposable = vc.present(presentation.onDismiss {
                guard let isCollapsed = self.isCollapsed.value else {
                    assertionFailure("Should not happen because once the collapsed state is determined it should not turn to nil")
                    return
                }
                if isCollapsed && !immediate {
                    self.deselect()
                }
            }).disposable

            detailBag.dispose()
            immediate = false
            detailBag += presentDisposable
        }

        return bag
    }

    /// Setups a `presentation` callback that will be called when details should be presented and where the returned presentation will be presented on `vc` .
    /// Before `presentation` is called any presentation returned by a previous call to `presentation` will be dismissed.
    /// The `presentation` callback will be called with signal for previous and next actions, useful to setup buttons to step between detail views.
    func presentDetailWithPreviousNext(on vc: UIViewController, presentation: @escaping (IndexAndElement?, ReadSignal<(() -> Void)?>, ReadSignal<(() -> Void)?>) -> DisposablePresentation?) -> Disposable {
        return presentDetail(on: vc) { indexAndElement in
            guard let indexAndElement = indexAndElement else {
                return presentation(nil, ReadSignal(nil), ReadSignal(nil))
            }

            let previous = self.keepSelection.elementsSignal.index(before: indexAndElement.element,
                                                                   isSame: self.keepSelection.isSame).map {
                $0.map { i in { self.select(index: i) } }
            }

            let next = self.keepSelection.elementsSignal.index(after: indexAndElement.element,
                                                               isSame: self.keepSelection.isSame).map {
                $0.map { i in { self.select(index: i) } }
            }

            return presentation(indexAndElement, previous, next)
        }
    }
}

public extension SignalProvider where Value: BidirectionalCollection {
    /// Returns a signal that will signal when index before `element` is updated.
    func index(before element: Element, isSame: @escaping (Element, Element) -> Bool) -> CoreSignal<Kind.DropWrite, Value.Index?> {
        return map { collection in
            guard let index = collection.firstIndex(where: { isSame(element, $0) }), index != collection.startIndex else { return nil }
            return collection.index(before: index)
        }
    }
}

public extension SignalProvider where Value: Collection {
    /// Returns a signal that will signal when index after `element` is updated.
    typealias Element = Value.Iterator.Element
    func index(after element: Element, isSame: @escaping (Element, Element) -> Bool) -> CoreSignal<Kind.DropWrite, Value.Index?> {
        return map { collection in
            guard let index = collection.firstIndex(where: { isSame(element, $0) }) else { return nil }
            let next = collection.index(after: index)
            return next != collection.endIndex ? next : nil
        }
    }
}

public extension CoreSignal where Value == (() -> Void)? {
    /// Will bind the action of `self` to `signal`, so that when `signal` signals, action (if any) will be called.
    func bindTo<S: SignalProvider>(on scheduler: Scheduler = .current, _ signal: S) -> Disposable where S.Value == () {
        return onValueDisposePrevious(on: scheduler) { action in
            action.map { signal.onValue($0) }
        }
    }
}
