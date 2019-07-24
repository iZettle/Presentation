//
//  CustomAdaptivePresentationDelegate.swift
//  Presentation
//
//  Created by Vasil Blanco-Nunev on 2019-07-19.
//  Copyright © 2019 iZettle. All rights reserved.
//

import UIKit
import Flow

public final class CustomAdaptivePresentationDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
    private let willDismissCallbacker = Callbacker<()>()
    private let didAttemptToDismissCallbacker = Callbacker<()>()
    private let didDismissCallbacker = Callbacker<()>()

    /// A signal that fires when a modal presentation will get dismissed by swiping down
    public var willDismissSignal: Signal<()> {
        return Signal(callbacker: willDismissCallbacker)
    }

    /// A signal that fires when a modal presentation attemts to get dismissed by swiping down
    /// For this to get called, the view controller needs to set `isModalInPresentation` to `true`
    public var didAttemptToDismissSignal: Signal<()> {
        return Signal(callbacker: didAttemptToDismissCallbacker)
    }

    /// A signal that fires when a modal presentation gets dismissed by swiping down
    public var didDismissSignal: Signal<()> {
        return Signal(callbacker: didDismissCallbacker)
    }

    var allowSwipeDismissAlways: Bool = false
}

#if compiler(>=5.1)
@available(iOS 13.0, *)
public extension CustomAdaptivePresentationDelegate {
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        willDismissCallbacker.callAll()
    }

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        didAttemptToDismissCallbacker.callAll()
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        didDismissCallbacker.callAll()
    }

    /// Checks whether a presentation controller should allow to dismiss from a swipe down action.
    /// If an option `.allowSwipeDismissAlways` is set to the presentation then all views inside a navigation stack
    /// will be able to be swiped down.
    ///
    /// By default on an navigation stack only the first view is allowed to be dismissed by swiping down.
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        guard !allowSwipeDismissAlways else {
            return true
        }

        guard let nc = (presentationController.presentedViewController as? UINavigationController) else {
            return true
        }

        return nc.viewControllers.count <= 1
    }
}

public extension UIViewController {
    /// A custom delegate  that allows you to listen to a Signals for adaptive presentations.
    ///
    /// **Warning:** When presenting using Presentation, do not use your own presentationController delegate.
    /// Presentation is performing extra work on this delegate to make sure things are disposed properly.
    var customAdaptivePresentationDelegate: CustomAdaptivePresentationDelegate? {
        get { return associatedValue(forKey: &customAdaptivePresentationDelegateKey) }
        set { objc_setAssociatedObject(self, &customAdaptivePresentationDelegateKey, newValue, .OBJC_ASSOCIATION_ASSIGN) }
    }
}

private var customAdaptivePresentationDelegateKey = false
#endif
