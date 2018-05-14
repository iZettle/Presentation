//
//  KeepSelection.swift
//  Presentation
//
//  Created by Måns Bernhardt on 2017-08-01.
//  Copyright © 2017 iZettle. All rights reserved.
//

import Foundation
import Flow

/// Helper that tries to keep at least one element (if not empty) selected as well to maintain any selected element when it is being moved.
public final class KeepSelection<Elements: BidirectionalCollection>: SignalProvider {
    public typealias Index = Elements.Index
    public typealias Element = Elements.Iterator.Element
    public typealias IndexAndElement = (index: Index, element: Element)
    
    private let current = ReadWriteSignal<IndexAndElement?>(nil)
    private let bag = DisposeBag()

    var elements: Elements {
        return elementsSignal.value
    }
    let elementsSignal: ReadSignal<Elements>
    let isSame: (Element, Element) -> Bool

    /// Creates a new instance using changes in `elements` to maintain the selected index (provided signal), using `isSame` to compare elements for equality.
    public init(elements: ReadSignal<Elements>, isSame: @escaping (Element, Element) -> Bool) {
        self.elementsSignal = elements.shared() // To make current more efficient
        self.isSame = isSame
        bag += self.elementsSignal.atOnce().atOnce().latestTwo().map { [weak self] oldElements, elements -> (Elements, Index)? in
            guard let `self` = self else { return nil }
            
            let currentIndex = self.current.value?.index
            guard let oldIndex = currentIndex, oldIndex < oldElements.endIndex else {
                return elements.isEmpty ? nil : (elements, elements.startIndex)
            }
            
            let oldItem = oldElements[oldIndex]
            if let newIndex = elements.index(where: { isSame($0, oldItem) }) {
                return (elements, newIndex)
            }
            
            // Search forward to see if any of the items in old is still in new
            for oldItem in oldElements[oldElements.index(after: oldIndex)..<oldElements.endIndex] {
                guard let index = elements.index(where: { isSame($0, oldItem) }) else {
                    continue
                }
                return (elements, index)
            }
            
            // Search backward to see if any of the items in old is still in new
            for oldItem in oldElements[oldElements.startIndex..<oldIndex].reversed() {
                guard let index = elements.index(where: { isSame($0, oldItem) }) else {
                    continue
                }
                let nextIndex = elements.index(after: index)
                return (elements, nextIndex != elements.endIndex ? nextIndex : index)
            }
            
            return elements.isEmpty ? nil : (elements, elements.startIndex)
        }.map { $0.map { ($1, $0[$1]) } }.bindTo(current)
    }
    
    /// Returns a signal the will signal when the selected index and element is updated.
    public var providedSignal: ReadSignal<IndexAndElement?> {
        return current.readOnly()
    }
    
    /// Updates the selected index.
    public func select(index: Index) {
        current.value = (index, elements[index])
    }
}
