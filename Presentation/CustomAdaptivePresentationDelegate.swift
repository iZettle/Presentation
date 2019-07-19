//
//  CustomAdaptivePresentationDelegate.swift
//  Presentation
//
//  Created by Vasil Blanco-Nunev on 2019-07-19.
//  Copyright © 2019 iZettle. All rights reserved.
//

import UIKit
import Flow

public class CustomAdaptivePresentationDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
    private let didAttemptToDismissCallbacker = Callbacker<()>()

    /// A signal that fires when a modally presented view controller is attempting to be dismissed from a swipe down action
    ///
    /// The view will attempt to dismiss only when the  view controller's`.isModalInPresentation` is set to true
    public var didAttemptToDismissSignal: Signal<()> {
        return Signal(callbacker: didAttemptToDismissCallbacker)
    }

    @available(iOS 13.0, *)
    public func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        self.didAttemptToDismissCallbacker.callAll()
    }
}

public extension UIViewController {
    /// A custom delegate  that allows you to listen to a Signal when a modally presented view attepts to dismiss itself.
    ///
    /// **Warning:** When presenting using Presentation, do not use your own custom delegate.
    /// Presentation is performing extra work on this delegate to make sure things are disposed properly.
    var customAdaptivePresentationDelegate: CustomAdaptivePresentationDelegate {
        get { return associatedValue(forKey: &customAdaptivePresentationDelegateKey, initial: CustomAdaptivePresentationDelegate()) }
        set { setAssociatedValue(newValue, forKey: &customAdaptivePresentationDelegateKey) }
    }
}

private var customAdaptivePresentationDelegateKey = false
