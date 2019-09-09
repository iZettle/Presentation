//
//  CustomAdaptivePresentationDelegate.swift
//  Presentation
//
//  Created by Vasil Blanco-Nunev on 2019-07-19.
//  Copyright © 2019 iZettle. All rights reserved.
//

import UIKit
import Flow

/// Exposes a reactive interface for a delegate conforming to `UIAdaptivePresentationControllerDelegate`
public final class CustomAdaptivePresentationDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
    public var adaptivePresentationStyle = Delegate<(UIPresentationController, UITraitCollection?), UIModalPresentationStyle>()
    public var viewControllerForAdaptivePresentationStyle = Delegate<(UIPresentationController, UIModalPresentationStyle), UIViewController?>()
    public var shouldDismiss = Delegate<UIPresentationController, Bool>()

    private let willPresentCallbacker = Callbacker<WillPresentAdaptivelyInput>()
    private let willDismissCallbacker = Callbacker<UIPresentationController>()
    private let didAttemptToDismissCallbacker = Callbacker<UIPresentationController>()
    private let didDismissCallbacker = Callbacker<UIPresentationController>()

    public typealias WillPresentAdaptivelyInput = (UIPresentationController, UIModalPresentationStyle, UIViewControllerTransitionCoordinator?)

    public var willPresentSignal: Signal<WillPresentAdaptivelyInput> {
        return Signal(callbacker: willPresentCallbacker)
    }

    /// A signal that fires on iOS 13+ when a modal presentation will get dismissed by swiping down.
    ///
    /// - Note: It fires when the dismissed view controller has `isModalInPresentation` set to `false`
    public var willDismissSignal: Signal<UIPresentationController> {
        return Signal(callbacker: willDismissCallbacker)
    }

    /// A signal that fires on iOS 13+ when a modal presentation attemts to get dismissed by swiping down
    ///
    /// - Note: For this to get called, the dismissed view controller needs to have `isModalInPresentation` set to `true`
    public var didAttemptToDismissSignal: Signal<UIPresentationController> {
        return Signal(callbacker: didAttemptToDismissCallbacker)
    }

    /// A signal that fires on iOS 13+ when a modal presentation gets dismissed by swiping down
    public var didDismissSignal: Signal<UIPresentationController> {
        return Signal(callbacker: didDismissCallbacker)
    }

    // MARK: - UIAdaptivePresentationControllerDelegate
    public func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return adaptivePresentationStyle.call((controller, nil)) ?? controller.presentationStyle
    }

    public func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return adaptivePresentationStyle.call((controller, traitCollection)) ?? controller.presentationStyle
    }

    public func presentationController(_ presentationController: UIPresentationController, willPresentWithAdaptiveStyle style: UIModalPresentationStyle, transitionCoordinator: UIViewControllerTransitionCoordinator?) {
        willPresentCallbacker.callAll(with: (presentationController, style, transitionCoordinator))
    }
}

#if compiler(>=5.1)
@available(iOS 13.0, *)
public extension CustomAdaptivePresentationDelegate {
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        willDismissCallbacker.callAll(with: presentationController)
    }

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        didAttemptToDismissCallbacker.callAll(with: presentationController)
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        didDismissCallbacker.callAll(with: presentationController)
    }

    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        return shouldDismiss.call(presentationController) ?? true
    }
}
#endif

public extension UIViewController {
    /// A custom delegate that allows you to listen to signals for adaptive presentations.
    ///
    /// **Warning:** When presenting using Presentation, do not use your own presentationController delegate.
    /// Presentation is performing extra work on this delegate to make sure things are disposed properly.
    var customAdaptivePresentationDelegate: CustomAdaptivePresentationDelegate? {
        get { return associatedValue(forKey: &customAdaptivePresentationDelegateKey) }
        set { objc_setAssociatedObject(self, &customAdaptivePresentationDelegateKey, newValue, .OBJC_ASSOCIATION_ASSIGN) }
    }
}

private var customAdaptivePresentationDelegateKey = false
