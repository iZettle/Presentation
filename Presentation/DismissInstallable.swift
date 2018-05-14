//
//  DismissInstallable.swift
//  Presentation
//
//  Created by Måns Bernhardt on 2017-03-10.
//  Copyright © 2017 iZettle. All rights reserved.
//

import UIKit
import Flow


public extension UIViewController {
    // An optional bar item to install when being presented
    var dismissBarItem: UIBarButtonItem? {
        get { return associatedValue(forKey: &installDismissKey) }
        set { setAssociatedValue(newValue, forKey: &installDismissKey) }
    }
    
    /// Returns a signal that will install `self`'s `dismissBarItem` if any and signal when it's beeing pressed.
    /// - Note: Useful when implementing a custom `PresentationStyle`
    func installDismissButton() -> Signal<()> {
        return Signal { c in
            let bag = DisposeBag()
            if let dismiss = self.dismissBarItem {
                bag += self.installDismissBarItem(dismiss)
                bag += dismiss.onValue(c)
            }
            return bag
        }
    }
    
    /// Installs `barItem` using any conformance to `DismissInstallable` or else set `barItem` to the left most item.
    func installDismissBarItem(_ barItem: UIBarButtonItem) -> Disposable {
        guard let install = self as? DismissInstallable else {
            // Delay to next run-loop to avoid issues with item becoming invisible in some cases, when it is set to early.
            DispatchQueue.main.async {
                self.navigationItem.setLeftBarButtonItems((self.navigationItem.leftBarButtonItems ?? []) + [barItem], animated: false)
            }
            
            return Disposer {
                guard let index = self.navigationItem.leftBarButtonItems?.index(of: barItem) else { return }
                self.navigationItem.leftBarButtonItems?.remove(at: index)
            }
        }
        
        return install._installDismissBarItem(barItem)
    }
}

/// Helper method that can be passed as `present()`'s configure argument:
///
///     vc.present(vc, configure: dismiss(UIBarButtonItem(...)))
///
/// - Note: Will set `UIViewController.dismissBarItem` to `dismissBarItem`
public func dismiss(_ dismissBarItem: UIBarButtonItem) -> (UIViewController, DisposeBag) -> () {
    return { vc, _ in vc.dismissBarItem = dismissBarItem }
}

/// Customization protocol to override the installation of a dismiss bar item.
public protocol DismissInstallable {
    func _installDismissBarItem(_ barItem: UIBarButtonItem) -> Disposable
}

extension UINavigationController: DismissInstallable {
    public func _installDismissBarItem(_ barItem: UIBarButtonItem) -> Disposable {
        let bag = DisposeBag()
        bag += viewControllersSignal
            .atOnce()
            .compactMap { $0.first }
            .onFirstValue { primary in
                bag += primary.installDismissBarItem(barItem)
        }
        return bag
    }
}

extension UISplitViewController: DismissInstallable {
    public func _installDismissBarItem(_ barItem: UIBarButtonItem) -> Disposable {
        let bag = DisposeBag()
        bag += signal(for: \.viewControllers)
            .atOnce()
            .compactMap { $0.first }
            .onFirstValue { primary in
                bag += primary.installDismissBarItem(barItem)
        }
        return bag
    }
}

private var installDismissKey = false
