//
//  UINavigationController+Signals.swift
//  Presentation
//
//  Created by Måns Bernhardt on 2016-02-26.
//  Copyright © 2016 iZettle. All rights reserved.
//

import UIKit
import Flow

public extension UINavigationController {
    /// Returns a signal that signals when a view controller is popped from `self`.
    var popViewControllerSignal: Signal<UIViewController> {
        return delegateSignal(for: { $0.popSignal })
    }
    
    /// Returns a signal that signals when `self` `viewController` is updated.
    var viewControllersSignal: ReadSignal<[UIViewController]> {
        return delegateSignal(for: { $0.viewControllersSignal }).readable(capturing: self.viewControllers)
    }
}

public extension UINavigationItem {
    /// Returns a signal that signals when the view controller using `self` is beeing popped.
    var popSignal: Signal<()> {
        return Signal(callbacker: popCallbacker)
    }
}


private var callbackerKey = false

private extension UINavigationController {
    func delegateSignal<Value>(for signal: @escaping (NavigationControllerDelegate) -> Signal<Value>) -> Signal<Value> {
        return Signal { c in
            let bag = DisposeBag()
            let delegate: NavigationControllerDelegate
            if let d = self.delegate as? NavigationControllerDelegate {
                delegate = d
            } else {
                delegate = NavigationControllerDelegate(delegate: self.delegate, navigationController: self)
                self.delegate = delegate
            }
            bag.hold(delegate)
            bag += signal(delegate).onValue(c)
            return bag
        }
    }
}

extension UINavigationItem {
    var popCallbacker: Callbacker<()> {
        return associatedValue(forKey: &callbackerKey, initial: Callbacker())
    }
}
    
private class NavigationControllerDelegate : NSObject, UINavigationControllerDelegate {
    weak var delegate: UINavigationControllerDelegate?
    weak var navigationController: UINavigationController?
    
    public init(delegate: UINavigationControllerDelegate?, navigationController: UINavigationController) {
        self.delegate = delegate
        self.navigationController = navigationController
    }
    
    fileprivate var popControllers = [UIViewController]()
    
    fileprivate var popCallbacker = Callbacker<UIViewController>()
    var popSignal: Signal<UIViewController> {
        return Signal(callbacker: popCallbacker)
    }
    
    fileprivate var viewControllersCallbacker = Callbacker<[UIViewController]>()
    var viewControllersSignal: Signal<[UIViewController]> {
        return Signal(callbacker: viewControllersCallbacker)
    }
    
    fileprivate func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        navigationController.view.endEditing(true) // End editing to help nc in modal to reset it's size
        delegate?.navigationController?(navigationController, willShow: viewController, animated: animated)
    }
    
    fileprivate func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        viewControllersCallbacker.callAll(with: navigationController.viewControllers)
        
        let removedControllers = popControllers.filter { !navigationController.viewControllers.contains($0) }
        removedControllers.forEach(popCallbacker.callAll)
        popControllers = navigationController.viewControllers
        delegate?.navigationController?(navigationController, didShow: viewController, animated: animated)
    }
    
    deinit {
        if let nc = navigationController , nc.delegate as? NavigationControllerDelegate == self {
            nc.delegate = self.delegate
        }
    }
}


