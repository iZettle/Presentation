//
//  UINavigationController+Presenting.swift
//  Presentation
//
//  Created by Måns Bernhardt on 2016-01-27.
//  Copyright © 2016 iZettle. All rights reserved.
//

import UIKit
import Flow


public extension PresentationOptions {
    /// Pushing and popping on a navigation controller defaults to batch subsequent operation from the same run-loop togeher. This options turnes that of.
    public static let disablePushPopCoalecing = PresentationOptions()
    
    /// Automatically pop a pushed view controller once the presentation completes.
    public static let autoPop = PresentationOptions()
    
    /// Any succeedingly pushed view controllers (pushed after itself) will be popped when `self` is cancelled or completed.
    public static let autoPopSuccessors = PresentationOptions()
    
    /// Equivalent to [.autoPop, .autoPopSuccessors]
    public static let autoPopSelfAndSuccessors: PresentationOptions = [.autoPop, .autoPopSuccessors]
}

extension UINavigationController: PresentingViewController {
    public func present(_ vc: UIViewController, options: PresentationOptions) -> PresentingViewController.Result {
        let dismissFuture = vc.installDismissButton().future.map { throw PresentError.dismissed }
        let pushFuture = self.pushViewController(vc, options: options)
        
        let dismiss = { () -> Future<()> in
            var futures = [Future<()>]()
            let nc = (vc.navigationController ?? self)
            if options.contains(.autoPop) {
                futures.append(nc.popViewController(vc, options: options))
            }
            
            if let index = nc.viewControllers.index(of: vc), options.contains(.autoPopSuccessors) {
                for vc in nc.viewControllers.suffix(from: index).dropFirst() {
                    futures.append(nc.popViewController(vc, options: options))
                }
            }
            return join(futures).toVoid()
        }
        
        return (Flow.select(dismissFuture, or: pushFuture).toVoid(), dismiss)
    }
}

/// Customization of the default title used by the navigation controller back button.
public var customNavigationBackButtonWithTitle: (String) -> UIBarButtonItem? = { _ in nil }

public extension UINavigationController {
    /// Push `viewController` onto `self` and return a future that completes once the animation completes.
    @discardableResult
    func pushViewController(_ viewController: UIViewController, options: PresentationOptions) -> Future<()> {
        return Future { c in
            let pp = PushPoper(vc: viewController, animated: options.animated, disableCoalecing: options.contains(.disablePushPopCoalecing)) {
                c($0)
            }
            self.append(pp)
            return pp.bag
        }
    }
    
    /// Pop `viewController` from `self` and return a future that completes once the animation completes.
    @discardableResult
    func popViewController(_ viewController: UIViewController, options: PresentationOptions) -> Future<()> {
        return Future { c in
            let pp = PushPoper(vc: viewController, animated: options.animated, disableCoalecing: options.contains(.disablePushPopCoalecing), isPopping: true) { _ in
                c(.success)
            }
            self.append(pp)
            return pp.bag
        }
    }
}

private class PushPoper: NSObject {
    let vc: UIViewController
    let animated: Bool
    let disableCoalecing: Bool
    weak var _onComplete: Box<((Result<()>) -> ())>?
    var onComplete: (Result<()>) -> () {
        return _onComplete?.unbox ?? { _ in }
    }
    let isPopping: Bool
    let bag = DisposeBag()
    
    init(vc: UIViewController, animated: Bool, disableCoalecing: Bool = false, isPopping: Bool = false, onComplete: @escaping (Result<()>) -> ()) {
        self.vc = vc
        self.animated = animated
        self.disableCoalecing = disableCoalecing
        self.isPopping = isPopping
        let onComplete = Box(onComplete)
        self._onComplete = onComplete
        bag.hold(onComplete) // hold on, keeping reference of onComplete inside the bag to avoid potential retain cycles  (PushPoper > onComplete > UINavigationController > PushPoper)
    }
}

private var pushPopersKey = false

// Helper to coalesce (and cancel out push/pops) to work around UINavigationController animation issues when push/pops several times during the same run-loop
private extension UINavigationController {
    var pushPopers: [PushPoper] {
        get { return associatedValue(forKey: &pushPopersKey, initial: []) }
        set { setAssociatedValue(newValue, forKey: &pushPopersKey) }
    }
    
    func append(_ pushPoper: PushPoper) {
        if let i = pushPopers.index(where: { $0.vc == pushPoper.vc && !$0.isPopping }) , pushPoper.isPopping {
            pushPopers.remove(at: i)
            return
        }
        
        pushPopers.append(pushPoper)
        if (pushPoper.disableCoalecing || self.viewControllers.isEmpty) { // not coalescing if no viewcontroller is set yet, in order to not display an empty navigation controller
            self.processPushPopers()
        } else {
            DispatchQueue.main.async {
                self.processPushPopers()
            }
        }
    }
    
    func processPushPopers() {
        guard !pushPopers.isEmpty else { return }
        
        var vcs = viewControllers
        
        var animated = false
        for pp in pushPopers {
            animated = animated || pp.animated
            if pp.isPopping {
                _ = vcs.index(of: pp.vc).map { vcs.remove(at: $0) }
            } else {
                guard !vcs.contains(pp.vc) else {
                    pp.onComplete(.failure(PresentError.alreadyPresented))
                    if let i = pushPopers.index(of: pp) {
                        pushPopers.remove(at: i)
                    }
                    continue
                }
                if let lastVC = vcs.last, let item = customNavigationBackButtonWithTitle(lastVC.title ?? "") {
                    lastVC.navigationItem.backBarButtonItem = item
                }
                vcs.append(pp.vc)
            }
        }
        
        if vcs.count == viewControllers.count {
            animated = false
        } else if vcs.count < viewControllers.count {
            animated = animated && vcs.last.map({ viewControllers.contains($0) }) ?? false
        } else if vcs.count > viewControllers.count {
            animated = animated && viewControllers.count > 0
        }
        
        if let t = transitionCoordinator, !animated {
            // If we update the vcs while the nc (self) is being presented, the nc gets lost and controls in the the presented vcs can't become first responders.
            // Moving presentation inside transition animate fixes issue.
            let willAnimate = t.animate(alongsideTransition: { context in
                let wasEnabled = UIView.areAnimationsEnabled
                UIView.setAnimationsEnabled(false)
                self.setViewControllers(vcs, animated: false)
                UIView.setAnimationsEnabled(wasEnabled)
            })
            
            if !willAnimate { // if the animation block wont't be called, fallback to normal setting up of vcx
                setViewControllers(vcs, animated: animated)
            }
        } else {
            setViewControllers(vcs, animated: animated)
        }
        
        
        func finalizeProcessedPushPoppers() {
            let processedPushPopers = pushPopers.filter { pp in (pp.isPopping && !viewControllers.contains(pp.vc)) || (!pp.isPopping && viewControllers.contains(pp.vc)) }
            pushPopers = pushPopers.filter { pp in !processedPushPopers.contains(pp) }
            
            for pp in processedPushPopers {
                animated = animated || pp.animated
                if pp.isPopping {
                    pp.onComplete(.success)
                } else {
                    listenOnPop(for: pp)
                }
            }
        }
        
        finalizeProcessedPushPoppers()
        
        guard vcs == viewControllers else { // transition in progress let's try again next run-loop
            DispatchQueue.main.async {
                finalizeProcessedPushPoppers()
                self.processPushPopers() // in case there are some remaining push popers at this point
            }
            return
        }
    }
    
    func listenOnPop(for pp: PushPoper) {
        popSignalPushPopers.append(Weak(pp))
        pp.bag += popViewControllerSignal.filter { $0 == pp.vc }.onFirstValue { _ in
            pp.vc.navigationItem.popCallbacker.callAll(with: ())
            pp.onComplete(.success)
        }
    }
    
    var popSignalPushPopers: [Weak<PushPoper>] {
        get { return associatedValue(forKey: &popSignalPushPopersKey, initial: []) }
        set { setAssociatedValue(newValue, forKey: &popSignalPushPopersKey) }
    }
}

extension UINavigationController {
    func transferViewControllers(from: UINavigationController) {
        viewControllers += from.viewControllers
        for pp in from.popSignalPushPopers.compactMap({ $0.value }) {
            let onComplete = pp._onComplete
            pp.bag.dispose()
            pp._onComplete = onComplete
            pp.bag += {
                _ = onComplete // hold on, keeping reference of onComplete inside the bag to avoid potential retain cycles  (PushPoper > onComplete > UINavigationController > PushPoper)
            }
            listenOnPop(for: pp)
        }
        from.popSignalPushPopers.removeAll()
    }
}

private final class Box<A> {
    let unbox: A
    init(_ value: A) { unbox = value }
}

private var popSignalPushPopersKey = false
