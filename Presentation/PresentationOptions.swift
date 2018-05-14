//
//  PresentationOptions.swift
//  Presentation
//
//  Created by Måns Bernhardt on 2017-03-15.
//  Copyright © 2017 iZettle. All rights reserved.
//

import UIKit
import Flow


/// Options for configuring different aspects of a presentation.
///
/// - Note: Not all options makes sense for all presentation styles.
/// - Note: New options are added use `PresentationOptions()` to allocate a unique value to the option.
///
///     `static let myOption = PresentationOptions()`
public struct PresentationOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public extension PresentationOptions {
    /// Captures any current first responder just before a presentation and restores it after the presentation is done.
    static let restoreFirstResponder = PresentationOptions()
  
    /// Embed the presented view contrroller in a navigation controller unless the presenting controller is already in a navigation controller.
    static let embedInNavigationController = PresentationOptions()

    /// Present self in the master view if the presenting controller has a master and detail view such as the split controller.
    static let showInMaster = PresentationOptions()

    /// Allow tapping outside the presented view controller to dismiss the presentation.
    static let tapOutsideToDismiss = PresentationOptions()

    /// Will immediately fail the presentation if it cannot be performed at once, such as when presenting modally and another view controller is already being presented modally.
    static let failOnBlock = PresentationOptions()

    /// At dismiss, complete the returned future, without waiting for the dismiss animation to complete.
    static let dontWaitForDismissAnimation = PresentationOptions()

    /// Disable any presentation animations.
    static let unanimated = PresentationOptions()

    /// Default options used unless any options are explicity passed when presented: `[embedInNavigationController]`
    static let defaults: PresentationOptions = [embedInNavigationController]
}

public extension PresentationOptions {
    init(line: Int = #line) { // adding a default arg works around and issue where the empty init was called by the system sometimes and exhusted the available options.
        rawValue = 1 << nextPresentationOptions
        nextPresentationOptions += 1
    }
}
private var nextPresentationOptions = 0

public extension PresentationOptions {
    /// Boolean indicating whether animation temporary disabled.
    static var animated: Bool { return performUnanimatedCount == 0 }
    
    /// Boolean indicating whether a presentation style should animate or not.
    var animated: Bool { return performUnanimatedCount == 0 && !contains(.unanimated) }
}
private var performUnanimatedCount = 0

public extension PresentationOptions {
    /// Disables presentation animations while executing `function`.
    static func performUnanimated<T>(_ function: () -> T) -> T {
        performUnanimatedCount += 1
        defer { performUnanimatedCount -= 1 }
        return function()
    }
}

/// Customization point to override the creation of navigation controllers. Defaults to `UINavigationController()`.
public var customNavigationController: (_ options: PresentationOptions) -> UINavigationController = { _ in UINavigationController() }

public extension UIViewController {
    /// Helper used by presentation styles to embed `self` in a navigation controller if options contains `.embedInNavigationController`
    func embededInNavigationController(_ options: PresentationOptions) -> UIViewController {
        // Add protocol
        guard options.contains(.embedInNavigationController) && !(self is UINavigationController) && !(self is UISplitViewController) && !(self is UIAlertController) else { return self }
        let nc = customNavigationController(options)
        nc.transferDebugPresentationInfo(from: self)
        nc.viewControllers = [ self ]
        return nc
    }
    
    /// Helper used by presentation styles to implement the option `.restoreFirstResponder`
    func restoreFirstResponder(_ options: PresentationOptions) -> Disposable {
        guard options.contains(.restoreFirstResponder) else { return NilDisposer() }

        let responder = firstResponder
        return Disposer {
            responder?.becomeFirstResponder()
        }
    }
}

extension UIResponder {
    @nonobjc var firstResponder: UIResponder? {
        // Send a message will a nil responder will walk the responder chain an call __findFirstResponder on responders that participate in the responder chain. If the participant is not the firstResponder continue with its children if the participant is a view.
        // https://stackoverflow.com/questions/1823317/get-the-current-first-responder-without-using-a-private-api
        
        _currentFirstResponder = nil
        UIApplication.shared.sendAction(#selector(UIResponder.__findFirstResponder), to: self, from: nil, for: nil)
        
        guard let first = _currentFirstResponder, !first.isFirstResponder else {
            return _currentFirstResponder
        }
        
        let subviews = (first as? UIView)?.subviews ?? (first as? UIViewController).map { [$0.view] } ?? []
        
        for view in subviews {
            if let v = view.firstResponder {
                return v
            }
        }
        
        return nil
    }
    
    @objc func __findFirstResponder(sender: AnyObject) {
        _currentFirstResponder = self
    }
}

private var _currentFirstResponder: UIResponder? = nil






