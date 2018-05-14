//
//  PresentationStyle.swift
//  Presentation
//
//  Created by Måns Bernhardt on 2017-03-15.
//  Copyright © 2017 iZettle. All rights reserved.
//

import UIKit
import Flow


/// A style of presentation, how a view controller is presented from a view controller given some options.
///
/// New styles are typically added as static extensions to `self` allowing it to be used in `present()` calls such as:
///
///     fromVc.present(vc, style: .modal)
public struct PresentationStyle {
    private let _present: (_ vc: UIViewController, _ from: UIViewController, _ options: PresentationOptions) throws -> Result

    public typealias Result = PresentingViewController.Result
    
    /// A name for debugging and comparing presentation styles.
    public let name: String
    
    /// Creates a new instance with `name` and `present` closure used when presenting a `vc` from `from` given some `options`.
    public init(name: String, present: @escaping (_ vc: UIViewController, _ from: UIViewController, _ options: PresentationOptions) throws -> Result) {
        self.name = name
        _present = present
    }
    
    /// Presents `viewController` from `fromViewController` using `options`.
    public func present(_ viewController: UIViewController, from fromViewController: UIViewController, options: PresentationOptions) -> Result {
        do {
           return try _present(viewController, fromViewController, options)
        } catch {
            return (dismisser: { Future() }, result: Future(error: error))
        }
    }
}

public extension UIViewController {
    /// Customization point for overriding the style when presenting with the `default` style.
    var preferredPresentationStyle: PresentationStyle? {
        get { return associatedValue(forKey: &preferredPresentationStyleKey) }
        set { setAssociatedValue(newValue, forKey: &preferredPresentationStyleKey) }
    }
}
private var preferredPresentationStyleKey = false

public extension PresentationStyle {
    /// Present using a default fallback style, e.g. push if presented from a navigation controller or modally otherwise.
    ///
    /// - Note: Will ask the presenting view controller for a target and use that if available.
    /// - Note: Will attempt to show in the detail view unless the option `.showInMaster` is set.
    /// - Note: Will present using `preferredPresentationStyle` if set.
    static let `default` = PresentationStyle(name: "default") { vc, from, options in
        if let preferredPresentationStyle = vc.preferredPresentationStyle {
            return preferredPresentationStyle.present(vc, from: from, options: options)
        }
        
        var target = from.targetViewController(forAction: options.contains(.showInMaster) ? #selector(UIViewController.show) : #selector(UIViewController.showDetailViewController(_:sender:)), sender: nil)
        if let presenter = target as? PresentingViewController {
            return presenter.present(vc, options: options)
        }
        
        target = from.targetViewController(forAction: #selector(UIViewController.show), sender: nil)
        
        if let presenter = target as? PresentingViewController {
            return presenter.present(vc, options: options)
        }
        
        return modal.present(vc, from: from, options: options)
    }
    
    /// Boolean value indicating whether `self` is the `.default` style.
    var isDefault: Bool {
        return name == PresentationStyle.default.name
    }
    
    /// Present modally.
    /// - Note: If the presenting view controller is already modally presenting, the presentation will be queued up,
    ///   unless options contains `.failOnBlock` where the presentation will instead fail.
    static let modal = PresentationStyle(name: "modal") { _vc, from, options in
        guard from.presentedViewController == nil || !options.contains(.failOnBlock) else {
            throw PresentError.presentationBlockedByOtherPresentation
        }
        
        let vc = _vc.embededInNavigationController(options)
        return from.modallyPresentQueued(vc, animated: options.animated) {
            Future { c in
                let bag = DisposeBag()
                bag += _vc.installDismissButton().onValue { c(.failure(PresentError.dismissed)) }
                
                if vc.modalPresentationStyle == .popover, let popover = vc.popoverPresentationController {
                    let delegate = PopoverPresentationControllerDelegate() {
                        guard !bag.isEmpty else { return }
                        c(.failure(PresentError.dismissed))
                    }
                    popover.delegate = delegate
                    // auto dismissing if the source view is removed from the window
                    bag += popover.sourceView?.hasWindowSignal.filter { $0 == false }.toVoid().onValue {
                        c(.failure(PresentError.dismissed))
                    }
                    bag.hold(delegate)
                }
                
                return bag
            }
        }
    }
    
    /// Present in a popover from the `sourceView` and given the `permittedDirections`.
    static func popover(from sourceView: UIView, permittedDirections: UIPopoverArrowDirection = .any) -> PresentationStyle {
        return PresentationStyle(name: "popover") { _vc, from, options in
            guard from.presentedViewController == nil || !options.contains(.failOnBlock) else {
                throw PresentError.presentationBlockedByOtherPresentation
            }

            let vc = _vc.embededInNavigationController(options)
            
            vc.modalPresentationStyle = .popover
            
            return from.modallyPresentQueued(vc, animated: options.animated) {
                
                let popover = vc.popoverPresentationController
                popover?.permittedArrowDirections = permittedDirections
                popover?.sourceView = sourceView
                popover?.sourceRect = sourceView.bounds
                UIApplication.shared.keyWindow?.endEditing(true)
                return Future { c in
                    let bag = DisposeBag()
                    
                    if let popover = vc.popoverPresentationController {
                        let delegate = PopoverPresentationControllerDelegate() { c(.failure(PresentError.dismissed)) }
                        popover.delegate = delegate
                        bag.hold(delegate)
                    } else {
                        bag += _vc.installDismissButton().onValue { c(.failure(PresentError.dismissed)) }
                    }
                    
                    return bag
                }
            }
        }
    }
    
    /// Present in popover if iPad or modally if iPhone.
    static func popoverOrModal(from sourceView: UIView) -> PresentationStyle {
        if isIpad {
            return .popover(from: sourceView)
        } else {
            return .modal
        }
    }
    
    /// Present invisibly.
    static let invisible = PresentationStyle(name: "invisible") { vc, from, options in
        return (Future(), { Future() })
    }

    /// Present by embedding the view controller in `view`.
    /// - Parameter dynamicPreferredContentSize: Whether or not the child view controller should automatically update the parents preferredCOntentSize.
    static func embed(in view: UIView?, dynamicPreferredContentSize: Bool = true) -> PresentationStyle {
        return PresentationStyle(name: "embed") { vc, from, options in
            let result = Future<()> { c in
                let bag = DisposeBag()
                
                let parentView: ReadSignal<UIView> = view.map { ReadSignal($0) } ?? vc.signal(for: \.view).map { $0! }
                from.addChildViewController(vc)
                
                var movedToParent = false
                bag += parentView.atOnce().onValueDisposePrevious { parentView in
                    parentView.hasWindowSignal.atOnce().filter { $0 }.onFirstValue { _ in
                        UIView.performWithoutAnimation { // prevents animation when the parent vc is modallly presented
                            vc.view.frame = parentView.bounds // So it has already the correct frame and avoid some resize animation on iOS 9..
                            parentView.embedView(vc.view)
                            vc.view.layoutIfNeeded()
                        }
                        if !movedToParent {
                            vc.didMove(toParentViewController: from)
                            movedToParent = true
                        }
                    }
                }
                
                if dynamicPreferredContentSize {
                    bag += vc.signal(for: \.preferredContentSize).atOnce().onValue { size in
                        from.preferredContentSize = size
                        from.navigationController?.preferredContentSize = size
                    }
                }
                
                return bag
            }

            return (result, {
                vc.willMove(toParentViewController: nil)
                vc.view.removeFromSuperview()
                vc.removeFromParentViewController()
                return Future()
            })
        }
    }
}

extension UIView {
    @discardableResult
    func embedView(_ view: UIView) -> [NSLayoutConstraint] {
        let constraints = [
            leftAnchor.constraint(equalTo: view.leftAnchor),
            topAnchor.constraint(equalTo: view.topAnchor),
            rightAnchor.constraint(equalTo: view.rightAnchor),
            bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ]
        
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        addConstraints(constraints)
        return constraints
    }
}

private class PopoverPresentationControllerDelegate: NSObject, UIPopoverPresentationControllerDelegate {
    let didDismiss: () -> ()
    
    init(didDismiss: @escaping () -> ()) {
        self.didDismiss = didDismiss
    }
    
    fileprivate func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool {
        didDismiss()
        return false
    }
}

private var isIpad: Bool { return UIDevice.current.userInterfaceIdiom == .pad }


