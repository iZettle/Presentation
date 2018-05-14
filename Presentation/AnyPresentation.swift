//
//  AnyPresentable.swift
//  Presentation
//
//  Created by Måns Bernhardt on 2017-05-14.
//  Copyright © 2017 iZettle. All rights reserved.
//

import UIKit
import Flow


/// A type erased Presentable
public struct AnyPresentable<Matter, Result> {
    private let _materialize: () -> (Matter, Result)
}

extension AnyPresentable: Presentable {
    public func materialize() -> (Matter, Result) {
        return _materialize()
    }
}

public extension AnyPresentable {
    /// Creates a new instance where the `presentable` type has been anonymized (erased).
    init<P: Presentable>(_ presentable: P) where P.Matter == Matter, P.Result == Result {
        _materialize = presentable.materialize
    }
    
    /// Creates a new instance where the `presentable` type has been anonymized (erased) and its result will be transforms using `transform`.
    init<P: Presentable>(_ presentable: P, transform: @escaping (P.Result) -> Result) where P.Matter == Matter {
        _materialize = {
            let (matter, result) = presentable.materialize()
            return (matter, transform(result))
        }
    }

    /// Creates a new instance using `materialize` to materialize `self`.
    init(materialize: @escaping () -> (Matter, Result)) {
        _materialize = materialize
    }
}
