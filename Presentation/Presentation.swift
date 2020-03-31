//
//  Presentation.swift
//  Presentation
//
//  Created by Måns Bernhardt on 2017-04-21.
//  Copyright © 2017 iZettle. All rights reserved.
//

import UIKit
import Flow

/// A view controller presentable together with presentation parameters.
/// A `Presentation` allows holds actions and transforms to be called upon its presentation and dismissal
/// that can be set up using several convenience transformations such as:
///
///     let Presentation(...).onPresent {
///       ...
///     }.onDismiss {
///       ...
///     }.map { future in
///       future.map { ... }
///     }
public struct Presentation<P: Presentable> where P.Matter: UIViewController {
    /// The presentable wrapped by `self`.
    public var presentable: P

    /// The presentation style to use when presenting `self`.
    public var style: PresentationStyle

    /// The presentation options to use when presenting `self`.
    public var options: PresentationOptions

    /// The configuration to apply just before presenting `self`.
    public var configure: (P.Matter, DisposeBag) -> ()

    /// A transformation to apply on the `materialized()` result.
    public var transform: (P.Result) -> P.Result

    /// A callback that will be called once presentaion is done, either with `nil` if normally dismissed, or with an error if not.
    public var onDismiss: (Error?) -> ()
}

/// A presentation of a type erased presentable.
public typealias AnyPresentation<Context: UIViewController, Result> = Presentation<AnyPresentable<Context, Result>>

/// A presentation of a type erased presentable where the result is of type `Disposable`
public typealias DisposablePresentation = AnyPresentation<UIViewController, Disposable>

/// A presentation of a type erased presentable where the result is of type `Future<T>`
public typealias FuturePresentation<T> = AnyPresentation<UIViewController, Future<T>>

/// A presentation of a type erased presentable where the result is of type `Signal<T>`
public typealias SignalPresentation<T> = AnyPresentation<UIViewController, Signal<T>>

public extension Presentation {
    /// Creates a new instance
    init(_ presentable: P, style: PresentationStyle = .default, options: PresentationOptions = .defaults, configure: @escaping (P.Matter, DisposeBag) -> () = { _, _  in }) {
        self.presentable = presentable
        self.style = style
        self.options = options
        self.configure = { vc, bag in
            vc.updatePresentationTitle(for: presentable)
            configure(vc, bag)
        }
        self.transform = { $0 }
        self.onDismiss = { _ in }
    }

    /// Creates a new instance from a type erased presentable
    init<T: Presentable, Result>(_ presentable: T, style: PresentationStyle = .default, options: PresentationOptions = .defaults, configure: @escaping (T.Matter, DisposeBag) -> () = { _, _  in }) where P == AnyPresentable<UIViewController, Result>, T.Result == Result, T.Matter: UIViewController {
        self.presentable = AnyPresentable<UIViewController, Result>(presentable)
        self.style = style
        self.options = options
        self.configure = { vc, bag in
            vc.updatePresentationTitle(for: presentable)
            configure(vc as! T.Matter, bag)
        }
        self.transform = { $0 }
        self.onDismiss = { _ in }
    }

    /// Creates a new instance holding a type erased presentable that uses ´materialize´ to materialize itself.
    ///
    ///     Presentation {
    ///       // construct vc and result
    ///       return (vc, result)
    ///     }
    init<Result>(style: PresentationStyle = .default, options: PresentationOptions = .defaults, configure: @escaping (UIViewController, DisposeBag) -> () = { _, _  in }, materialize: @escaping () -> (UIViewController, Result)) where P == AnyPresentable<UIViewController, Result> {
        self.init(AnyPresentable(materialize: materialize), style: style, options: options, configure: configure)
    }

    /// Creates a new instance from `presentation` with a `UIViewController` matter type.
    init<T, Result>(_ presentation: Presentation<T>) where P == AnyPresentable<UIViewController, Result>, T.Result == Result {
        self.init(presentation.presentable, style: presentation.style, options: presentation.options, configure: presentation.configure)
        self.transform = presentation.transform
        self.onDismiss = presentation.onDismiss
    }
}

public extension Presentation where P == AnyPresentable<UIViewController, Disposable> {
    /// Creates a new instance from `presentation` with a `UIViewController` matter type and a `Disposable` result type.
    init<P, T>(_ presentation: Presentation<P>) where P.Result == Future<T> {
        self.init(presentation.map { $0.disposable })
    }
}

public extension Presentation where P == AnyPresentable<UIViewController, Future<()>> {
    /// Creates a new instance from `presentation` with a `UIViewController` matter type and a `Future<()>` result type.
    init<P>(_ presentation: Presentation<P>) where P.Result == Disposable {
        self.init(presentation.map { disposable in Future { _ in disposable } }) // Never complete
    }

    /// Creates a new instance from `presentation` with a `UIViewController` matter type and a `Future<T>` result type.
    init<P, T>(_ presentation: Presentation<P>) where P.Result == Future<T> {
        let voidPresentation = presentation.map { $0.toVoid() }
        self.init(voidPresentation.presentable, style: voidPresentation.style, options: voidPresentation.options, configure: voidPresentation.configure)
        self.transform = { voidPresentation.transform($0) }
        onDismiss = voidPresentation.onDismiss
    }
}

public extension Presentation {
    /// Returns a new presentation where the result will be transformed using `transform`.
    func map(_ transform: @escaping (P.Result) -> P.Result) -> Presentation {
        let presentationTransform = self.transform
        var new = self
        new.transform = { result in transform(presentationTransform(result)) }
        new.onDismiss = onDismiss

        return new
    }

    /// Returns a new presentation where the result will be transformed using `transform`.
    func map<Result>(_ transform: @escaping (P.Result) -> Result) -> Presentation<AnyPresentable<P.Matter, Result>> {
        let presentationTransform = self.transform
        let anyPresentable = AnyPresentable(presentable, transform: { result in transform(presentationTransform(result)) })
        var new = Presentation<AnyPresentable<P.Matter, Result>>(anyPresentable, style: style, options: options, configure: configure)
        let onDismiss = self.onDismiss
        new.onDismiss = { onDismiss($0) }
        return new
    }

    /// Returns a new presentation where `callback` will be called when `self` is being presented.
    func onPresent(_ callback: @escaping () -> ()) -> Presentation {
        return map {
            callback()
            return $0
        }
    }

    /// Returns a new presentation where `callback` will be called when `self` is being dismissed.
    func onDismiss(_ callback: @escaping () -> ()) -> Presentation {
        let onDismiss = self.onDismiss
        var new = self

        new.onDismiss = {
            onDismiss($0)
            callback()
        }

        return new
    }

    /// Returns a new presentation where `callback` will be called with the value of a successful dismiss of `self`.
    func onValue<Value>(_ callback: @escaping (Value) -> ()) -> Presentation where P.Result == Future<Value> {
        let onDismiss = self.onDismiss
        var value: Value?
        var new = map { $0.onValue { value = $0 } }

        new.onDismiss = { error in
            onDismiss(error)
            if let value = value, error == nil {
                callback(value)
            }
        }

        return new
    }

    /// Returns a new presentation where `callback` will be called for every signaled value.
    func onValue<Kind, Value>(_ callback: @escaping (Value) -> ()) -> Presentation where P.Result == CoreSignal<Kind, Value> {
        return map { $0.atValue(callback) }
    }

    /// Returns a new presentation where `callback` will be called if `self` was dismiss with an error.
    func onError(_ callback: @escaping (Error) -> ()) -> Presentation {
        let onDismiss = self.onDismiss
        var new = self
        new.onDismiss = {
            onDismiss($0)
            if let error = $0 {
                callback(error)
            }
        }
        return new
    }

    /// Returns a new presentation where `configure` will be called at presentation.
    /// - Note: `self`'s `configure` will still be called before the provided `configure`.
    func addConfiguration(_ configure: @escaping (P.Matter, DisposeBag) -> ()) -> Presentation {
        var new = self
        let oldConfigure = new.configure
        new.configure = { vc, bag in
            oldConfigure(vc, bag)
            configure(vc, bag)
        }
        return new
    }
}

public extension UIViewController {
    /// Presents `presentation` on `self` and returns a future that if cancelled will abort and dismiss the presentation.
    @discardableResult
    func present<P>(_ presentation: Presentation<P>) -> Future<()> where P.Result == Disposable {
        let (vc, result) = presentation.presentable.materialize()
        return present(vc, style: presentation.style, options: presentation.options) { vc, bag -> () in
            presentation.configure(vc, bag)
            bag += presentation.transform(result)
        }.onResult { presentation.onDismiss($0.error) }
         .onCancel { presentation.onDismiss(PresentError.dismissed) }
    }

    /// Presents `presentation` on `self` and returns a future that will complete with the result of the presentation.
    /// - Note: The presentation can be aborted by canceling the returned future.
    @discardableResult
    func present<P, Value>(_ presentation: Presentation<P>) -> Future<Value> where P.Result == Future<Value> {
        let (vc, result) = presentation.presentable.materialize()
        return present(vc, style: presentation.style, options: presentation.options) { vc, bag -> Future<Value> in
            presentation.configure(vc, bag)
            return presentation.transform(result)
        }.onResult { presentation.onDismiss($0.error) }
         .onCancel { presentation.onDismiss(PresentError.dismissed) }
    }

    /// Presents `presentation` on `self` and returns a signal that will signal updates from the presentation.
    @discardableResult
    func present<P, S: SignalProvider, Value>(_ presentation: Presentation<P>) -> FiniteSignal<Value> where P.Result == S, S.Value == Value {
        let (vc, result) = presentation.presentable.materialize()
        return FiniteSignal<Value>(onEvent: { callback in
            self.present(vc, style: presentation.style, options: presentation.options) { vc, bag -> Future<Value> in
                Future { _ in
                    presentation.configure(vc, bag)
                    return FiniteSignal(presentation.transform(result)).onEvent(callback)
                }
            }.onError { callback(.end($0)) }
             .onResult { presentation.onDismiss($0.error) }
             .onCancel { presentation.onDismiss(PresentError.dismissed) }.disposable
        }).atError { error in presentation.onDismiss(error) }
    }
}

public extension UIViewController {
    /// Presents `presentable` on `self` and returns a future that if cancelled will abort and dismiss the presentation.
    @discardableResult
    func present<P: Presentable>(_ presentable: P, style: PresentationStyle = .default, options: PresentationOptions = .defaults, configure: @escaping (P.Matter, DisposeBag) -> () = { _, _  in }) -> Future<()> where P.Matter: UIViewController, P.Result == Disposable {
        return present(Presentation<P>(presentable, style: style, options: options, configure: configure))
    }

    /// Presents `presentable` on `self` and returns a future that will complete with the result of the presentation.
    /// - Note: The presentation can be aborted by canceling the returned future.
    @discardableResult
    func present<P: Presentable, Value>(_ presentable: P, style: PresentationStyle = .default, options: PresentationOptions = .defaults, configure: @escaping (P.Matter, DisposeBag) -> () = { _, _  in }) -> Future<Value> where P.Matter: UIViewController, P.Result == Future<Value> {
        return present(Presentation<P>(presentable, style: style, options: options, configure: configure))
    }

    /// Presents `presentable` on `self` and returns a signal that will signal updates from the presentation.
    func present<P: Presentable, S: SignalProvider, Value>(_ presentable: P, style: PresentationStyle = .default, options: PresentationOptions = .defaults, configure: @escaping (P.Matter, DisposeBag) -> () = { _, _  in }) -> FiniteSignal<Value> where P.Matter: UIViewController, P.Result == S, S.Value == Value {
        return present(Presentation<P>(presentable, style: style, options: options, configure: configure))
    }
}

/// A presentation of either left or right.
public typealias EitherPresentation<Left: Presentable, Right: Presentable> = Either<Presentation<Left>, Presentation<Right>> where Left.Matter: UIViewController, Right.Matter: UIViewController

public extension UIViewController {
    /// Presents either the left or right of `presentation` on `self`.
    @discardableResult
    func present<Left, Right>(_ presentation: EitherPresentation<Left, Right>) -> Future<()> where Left.Result == Right.Result, Left.Result == Disposable {
        switch presentation {
        case let .left(left):
            return present(left)
        case let .right(right):
            return present(right)
        }
    }

    /// Presents either the left or right of `presentation` on `self`.
    @discardableResult
    func present<Left, Right, LeftValue, RightValue>(_ presentation: EitherPresentation<Left, Right>) -> Future<Either<LeftValue, RightValue>> where Left.Result == Future<LeftValue>, Right.Result == Future<RightValue> {
        switch presentation {
        case let .left(left):
            return present(left).map { .left($0) }
        case let .right(right):
            return present(right).map { .right($0) }
        }
    }

    /// Presents either the left or right of `presentation` on `self`.
    @discardableResult
    func present<Left, Right, LS: SignalProvider, RS: SignalProvider, LeftValue, RightValue>(_ presentation: EitherPresentation<Left, Right>) -> FiniteSignal<Either<LeftValue, RightValue>> where Left.Result == LS, Right.Result == RS, LS.Value == LeftValue, RS.Value == RightValue {
        switch presentation {
        case let .left(left):
            return present(left).map { .left($0) }
        case let .right(right):
            return present(right).map { .right($0) }
        }
    }
}

public extension AnyPresentable where Matter == UIViewController {
    /// Creates a type erased insance of presentable where the matter is a `UIViewControler`.
    init<P: Presentable>(_ presentable: P) where P.Matter: UIViewController, P.Result == Result {
        self.init(materialize: presentable.materialize)
    }
}

public extension UIWindow {
    /// Presents `presentable` on `self` and set `self`'s `rootViewController` to the presented view controller and make `self` key and visible.
    /// - Parameter options: Only `.embedInNavigationController` is supported, defaults to `[]`
    func present<P: Presentable>(_ presentable: P, options: PresentationOptions = []) -> Disposable where P.Matter: UIViewController, P.Result == Disposable {
        let bag = DisposeBag()
        let (vc, disposable) = presentable.materialize()
        bag += disposable

        rootViewController = vc.embededInNavigationController(options)
        makeKeyAndVisible()

        bag.hold(self)

        return bag
    }
}

public extension Presentation {
    /// Creates a new instance with an `.invisible` presentation style where `invisibleResult`'s result is used as result when `self` is being presented.
    init<Result>(invisibleResult: @escaping () -> Result) where P == AnyPresentable<UIViewController, Result> {
        self.init(InvisiblePresentable(result: invisibleResult), style: .invisible, options: [])
    }
}

private struct InvisiblePresentable<Result>: Presentable {
    let result: () -> Result
    public func materialize() -> (UIViewController, Result) {
        return (UIViewController(), result())
    }
}

private extension UIViewController {
    func updatePresentationTitle<P: Presentable>(for presentable: P) {
        if let presentableIdentifier = (presentable as? PresentableIdentifierExpressible)?.presentableIdentifier {
            debugPresentationTitle = presentableIdentifier.value
        } else {
            let title = "\(type(of: presentable))"
            guard !title.hasPrefix("AnyPresentable<") else {
                return
            }
            debugPresentationTitle = title
        }
    }
}
