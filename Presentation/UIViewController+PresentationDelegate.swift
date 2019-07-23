//
//  UIViewController+PresentationDelegate.swift
//  Presentation
//
//  Created by Vasil Blanco-Nunev on 2019-07-19.
//  Copyright © 2019 iZettle. All rights reserved.
//

import UIKit
import Flow

public extension UIViewController {
    /// A custom delegate  that allows you to listen to a Signal when a modally presented view attepts to dismiss itself.
    ///
    /// **Warning:** When presenting using Presentation, do not use your own custom delegate.
    /// Presentation is performing extra work on this delegate to make sure things are disposed properly.
    var customAdaptivePresentationDelegate: UIAdaptivePresentationControllerDelegate? {
        get { return associatedValue(forKey: &customAdaptivePresentationDelegateKey) }
        set { setAssociatedValue(newValue, forKey: &customAdaptivePresentationDelegateKey) }
    }

    /// A signal that fires when a modally presented view controller is attempting to be dismissed from a swipe down action
    ///
    /// The view will attempt to dismiss only when the  view controller's`.isModalInPresentation` is set to true
    @available(iOS 13.0, *)
    var didAttemptToDismissSignal: Signal<()> {
        class Delegate: NSObject, UIAdaptivePresentationControllerDelegate {
            let callbacker = Callbacker<()>()
            public func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
                self.callbacker.callAll()
            }
        }
        return Signal { callback in
            let bag = DisposeBag()
            let delegate = (self.customAdaptivePresentationDelegate as? Delegate) ?? Delegate()
            bag.hold(delegate)
            self.customAdaptivePresentationDelegate = delegate
            bag += delegate.callbacker.addCallback(callback)

            return bag
        }
    }
}

private var customAdaptivePresentationDelegateKey = false
