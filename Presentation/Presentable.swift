//
//  Presentable.swift
//  Presentation
//
//  Created by Måns Bernhardt on 2016-09-14.
//  Copyright © 2016 iZettle. All rights reserved.
//

import UIKit
import Flow


/// Conforming types can be materialized to a `Matter` and a `Result`.
///
/// A conforming types typically contains information needed to construct a
/// `Matter` (e.g. a `UIViewController` or `UIView` subclass).
///
/// Most presentations are asynchronous and the `Result` type is normally one of:
/// - `Disposable`: The presentation has no natural ending and is typically dismissed by the presenter, e.g. presented in a tab.
/// - `Future<T>`: The presentation will end once with a result, e.g. presenting modally to collect information.
/// - `Signal<T>`: The presentation could signal values more than once, e.g. a pushed view that one could come back to by popping.
///
///
///     struct Login: Presentable {
///       var prefilledEmail: Email?
///
///       func materialize() -> (UIViewController, Future<User>) {
///         let vc = UIViewController()
///         return (vc, Future { completion in
///           // build UI
///           let bag = DisposeBag()
///           bag += loginButton.onValue { completion(...) }
///           return bag
///         }
///       }
///     }
///
/// Conforming types using a `UIViewController` `Matter` and a `Result` of either `Disposable`, `Signal` or `Future`
/// can be conveniently presented directly:
///
///     let login = Login(...)
///     fromViewController.present(login)
///
/// Or indirectly together with presentation parameters in a `Presentation`:
///
///     let presentation = Presentation(Login(...))
///     fromViewController.present(presentation)
///
///
public protocol Presentable {
    associatedtype Matter
    associatedtype Result

    /// Constructs a matter from `self` and returns it toghether with the result of presenting it.
    func materialize() -> (Matter, Result)
}
