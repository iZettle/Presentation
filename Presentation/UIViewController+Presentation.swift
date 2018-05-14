//
//  UIViewController+Presentation.swift
//  Presentation
//
//  Created by Måns Bernhardt on 2015-12-02.
//  Copyright © 2015 iZettle. All rights reserved.
//

import UIKit
import Flow

public extension UIViewController {
    /// Presents `viewController` on `self` and returns a future with the result of `function`'s returned future.
    /// - Parameter function: Called before presentation allowing configuration of ´viewController` as well as adding disposables to the provided bag that will be dipsosed once dismissed. Should return a future that completes the presentation.
    /// - Note: Once the future returned from `function` completes, the presentation will start being dismissed.
    /// - Note: The returned future will not complete until the dismiss animation completes, unless the `.dontWaitForDismissAnimation` option is provided.
    /// - Note: The presentation can be aborted by cancelling the returned future.
    @discardableResult
    func present<VC: UIViewController, Value>(_ viewController: VC, style: PresentationStyle = .default, options: PresentationOptions = .defaults, function: @escaping (VC, DisposeBag) -> Future<Value>) -> Future<Value> {
        let vc = viewController
        let root = rootViewController
        guard (root.isViewLoaded && root.view.window != nil) || unitTestDisablePresentWaitForWindow else {
            // Wait for root to be presented before presenting vc
            return root.signal(for: \.view).flatMapLatest { $0.hasWindowSignal.atOnce() }.filter { $0 }.future.flatMap { _ in
                self.present(vc, style: style, options: options, function: function)
            }
        }
        
        return Future { _completion in
            let bag = DisposeBag()
            
            let responder = self.restoreFirstResponder(options)
            
            let onDismissedBag = DisposeBag()
            onDismissedBag += responder
            
            var didComplete = false
            var dismiss = { Future() }
            func completion(_ result: Result<Value>) {
                guard !didComplete else { return }
                didComplete = true
                
                let complete = {
                    switch result {
                    case .success(let result):
                        log("\(self.presentationDescription) did end presentation of: \(vc.presentationDescription) with result: \(result)")
                    case .failure(let error):
                        log("\(self.presentationDescription) did end presentation of: \(vc.presentationDescription) with error: \(error)")
                    }
                    _completion(result)
                }
                
                if options.contains(.dontWaitForDismissAnimation) {
                    dismiss().always(onDismissedBag.dispose)
                    complete()
                } else {
                    dismiss().always(onDismissedBag.dispose).always(complete)
                }
            }
            
            bag += {
                guard !didComplete else { return }
                log("\(self.presentationDescription) did cancel presentation of: \(vc.presentationDescription)")
                _ = dismiss()
                onDismissedBag.dispose()
            }

            let future = function(vc, bag)

            log("\(self.presentationDescription) will '\(style.name)' present: \(vc.presentationDescription)")

            bag += future.onResult(completion)
            
            guard !didComplete else {
                // future completed before starting presentation, so just skip it.
                return bag
            }

            #if DEBUG
            self.trackMemoryLeaks(vc, whenDisposed: onDismissedBag)
            #endif
            
            let (result, dismisser) = style.present(vc, from: self, options: options)
            dismiss = dismisser
            
            bag += result.onError { error in
                if case PresentError.presentationNotPossible = error {
                    assertionFailure("Could not successfully present view controller")
                }
                completion(.failure(error))
            }.onValue {
                completion(.failure(PresentError.dismissed))
            }
            
            return bag
        }
    }
    
    /// Presents `viewController` on `self` and returns a future that will complete in the case of an error.
    /// - Parameter configure: Called before presentation allowing configuration of the view controller as well as adding disposables to the provided bag that will be dipsosed once dismissed.
    /// - Note: The presentation can be aborted by cancelling the returned future.
    @discardableResult
    func present<VC: UIViewController>(_ viewController: VC, style: PresentationStyle = .default, options: PresentationOptions = .defaults, configure: @escaping (VC, DisposeBag) -> () = { _,_  in }) -> Future<()> {
        return self.present(viewController, style: style, options: options) { vc, bag -> Future<()> in
            configure(vc, bag)
            return Future { _ in bag }
        }
    }
    
    /// Presents `viewController` on `self` and returns a signal that will signal the values signaled from `function`'s returned signal.
    /// - Parameter function: Called before presentation allowing configuration of the view controller as well as adding disposables to the provided bag that will be dipsosed once dismissed. Should return a signal.
    /// - Note: The presentation will not start until the returned signal has at least one listener.
    /// - Note: The presentation will be aborted and dismissed once there are no longer any listeners.
    /// - Note: The presentation can be aborted by cancelling the returned future.
    @discardableResult
    func present<VC: UIViewController, S: SignalProvider, Value>(_ vc: VC, style: PresentationStyle = .default, options: PresentationOptions = .defaults, function: @escaping (VC, DisposeBag) -> S) -> FiniteSignal<Value> where S.Value == Value {
        return FiniteSignal<Value>(onEvent: { callback in
            self.present(vc, style: style, options: options) { vc, bag -> Future<Value> in
                Future { _ in FiniteSignal(function(vc, bag)).onEvent(callback) }
            }.onError { error in
                callback(.end(error))
            }.disposable
        })
    }
}

/// Errors that might occur during a presentation
public enum PresentError: Error {
    // The presentation was dismissed.
    case dismissed
    
     // The presentation was not possible.
    case presentationNotPossible
    
    // The same view controller cannot be simultaneously presented more than one at the time.
    case alreadyPresented

    // Trying to present a e.g. a modal when one is already presented and the option `.failOnBlock` is used.
    case presentationBlockedByOtherPresentation
}

public extension UIViewController {
    /// Title used when logging presentations
    var debugPresentationTitle: String? {
        get { return associatedValue(forKey: &debugPresentationTitleKey) }
        set { setAssociatedValue(newValue, forKey: &debugPresentationTitleKey) }
    }
    
    /// Arguments used when logging presentations
    var debugPresentationArguments: [String: CustomStringConvertible?] {
        get { return associatedValue(forKey: &debugPresentationArgumentsKey, initial: [:]) }
        set { setAssociatedValue(newValue, forKey: &debugPresentationArgumentsKey) }
    }
    
    /// Setup `self`'s debug title and arguments to that of `viewController`.
    func transferDebugPresentationInfo(from viewController: UIViewController) {
        debugPresentationTitle = viewController.presentationTitle
        debugPresentationArguments = viewController.debugPresentationArguments
    }
}

/// Customization point to for presentation logging. Defaults to using `print()`
public var presentableLogPresentation: (_ message: @escaping @autoclosure () -> String, _ file: String, _ function: String, _ line: Int) -> () = { (message: () -> String, file, function, line) in
    print("\(file): \(function)(\(line)) - \(message())")
}

public extension UIViewController {
    /// Modally presents `viewController` on `self`
    /// - Parameter callback: Will be called once the presention is possible, where the returned future will complete the presentation.
    /// - Note: Helper for PresentationStyle implementations helper for queueing up modal presentations if already presenting.
    /// - Note: If a modal presention is already ongoing the presentation will be queued up.
    func modallyPresentQueued(_ viewController: UIViewController, animated: Bool, _ callback: @escaping () -> Future<()>) -> PresentingViewController.Result {
        let vc = viewController
        let from = targetViewController(forAction: #selector(UIViewController.present(_:animated:completion:)), sender: nil) ?? self
        let queue = from.associatedValue(forKey: &modalQueueKey, initial: FutureQueue())
        let willEnqueue = !queue.isEmpty
        let fromDescription = from == self ? presentationDescription : "\(self.presentationDescription)(\(from.presentationDescription))"
        if willEnqueue {
            log("\(fromDescription) will enqueue modal presentation of \(vc.presentationDescription)")
        }
        
        let dismissedCallbacker = Callbacker<Result<()>>()
        let resultCallbacker = Callbacker<Result<()>>()
        var hasBeenCancelled = false
        let _: Future<()> = queue.enqueue {
            guard !hasBeenCancelled else {
                throw PresentError.presentationNotPossible
            }
            
            guard from.presentedViewController == nil else {
                resultCallbacker.callAll(with: .failure(PresentError.presentationBlockedByOtherPresentation))
                throw PresentError.presentationBlockedByOtherPresentation
            }
            
            if willEnqueue {
                log("\(fromDescription) will dequeue modal presentation of \(vc.presentationDescription)")
            }
            
            from.present(vc, animated: animated)
            
            let f = callback().onResult(resultCallbacker.callAll)
            return Future(callbacker: dismissedCallbacker).always(f.cancel) // Block queue until dismissed.
        }
        
        let future = Future(callbacker: resultCallbacker).onCancel {
            hasBeenCancelled = true
        }
        
        let dismiss = { // Don't allow dismiss until presented
            vc.dismiss(animated: animated).onResult(dismissedCallbacker.callAll)
        }
        
        return (future, dismiss)
    }
}

func log(_ message: @escaping @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
    presentableLogPresentation(message, file, function, line)
}

var unitTestDisablePresentWaitForWindow = false

private var debugPresentationTitleKey = false
private var debugPresentationArgumentsKey = false

extension UIViewController {
    var presentationTitle: String {
        return debugPresentationTitle ?? title ?? self.title ?? "\(type(of: self))"
    }
    
    var presentationDescription: String {
        let arguments = debugPresentationArguments.compactMap { k, v in v.map { "\(k): \($0)" } }.joined(separator: ", ")
        guard !arguments.isEmpty else { return presentationTitle }
        return presentationTitle + "(\(arguments))"
    }
}

private extension UIViewController {
    var rootViewController: UIViewController {
        guard let parent = parent else { return self }
        return parent.rootViewController
    }
}


extension UIViewController {
    @discardableResult
    func present(_ vc: UIViewController, animated: Bool) -> Future<()> {
        return Future { c in
            self.present(vc, animated: animated, completion: { c(.success) })
            return NilDisposer()
        }
    }
    
    @discardableResult
    func dismiss(animated: Bool) -> Future<()> {
        return Future<()> { c in
            if let p = self.presentingViewController, p.presentedViewController == self {
                p.dismiss(animated: animated, completion: {
                    c(.success)
                })
            } else {
                c(.success) // Alerts dismisses themselves
            }
            return NilDisposer()
        }
    }
}


private var modalQueueKey = false

