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

    /// Present modally with the option to override `presentationStyle`, `transitionStyle` and `capturesStatusBarAppearance` settings.
    /// - Note: If the presenting view controller is already modally presenting, the presentation will be queued up,
    ///   unless options contains `.failOnBlock` where the presentation will instead fail.
    static func modally(presentationStyle: UIModalPresentationStyle? = nil, transitionStyle: UIModalTransitionStyle? = nil, capturesStatusBarAppearance: Bool? = nil) -> PresentationStyle {
        return PresentationStyle(name: "modally") { viewController, from, options in
            let vc = viewController.embededInNavigationController(options)

            if let presentationStyle = presentationStyle {
                vc.modalPresentationStyle = presentationStyle
            }

            if let transitionStyle = transitionStyle {
                vc.modalTransitionStyle = transitionStyle
            }

            if let capturesStatusBarAppearance = capturesStatusBarAppearance {
                vc.modalPresentationCapturesStatusBarAppearance = capturesStatusBarAppearance
            }

            return from.modallyPresentQueued(vc, options: options) {
                Future { completion in
                    let bag = DisposeBag()

                    // The presentationController of an alert controller should not have its delegate modified
                    if !(vc is UIAlertController) {
                        /**
                         Using a custom property instead of `viewController.presentationController?.delegate` because
                         of a memory leak in UIKit when accessing the presentation controller of a view controller
                         that's not going to be presented: https://github.com/iZettle/Presentation/pull/43#discussion_r307223478
                         */
                        let delegate = viewController.customAdaptivePresentationDelegate ?? CustomAdaptivePresentationDelegate()
                        bag.hold(delegate)
                        vc.presentationController?.delegate = delegate

                        bag += delegate.shouldDismiss.set { presentationController -> Bool in
                            guard !options.contains(.allowSwipeDismissAlways),
                            let nc = (presentationController.presentedViewController as? UINavigationController) else {
                                return true
                            }
                            return nc.viewControllers.count <= 1
                        }

                        bag += delegate.didDismissSignal.onValue { _ in
                            completion(.failure(PresentError.dismissed))
                        }
                    }

                    bag += viewController.installDismissButton().onValue {
                        completion(.failure(PresentError.dismissed))
                    }

                    if vc.modalPresentationStyle == .popover, let popover = vc.popoverPresentationController {
                        let delegate = PopoverPresentationControllerDelegate {
                            guard !bag.isEmpty else { return }
                            completion(.failure(PresentError.dismissed))
                        }
                        popover.delegate = delegate
                        // auto dismissing if the source view is removed from the window
                        bag += popover.sourceView?.hasWindowSignal.filter { $0 == false }.toVoid().onValue {
                            completion(.failure(PresentError.dismissed))
                        }
                        bag.hold(delegate)
                    }

                    return bag
                }
            }
        }
    }

    /// Present in modal.
    /// - Note: If the presenting view controller is already modally presenting, the presentation will be queued up,
    ///   unless options contains `.failOnBlock` where the presentation will instead fail.
    static let modal = PresentationStyle(name: "modal") { viewController, from, options in
        return modally().present(viewController, from: from, options: options)
    }

    /// Present in a popover from the `sourceView` and given the `permittedDirections`.
    static func popover(from sourceView: UIView, permittedDirections: UIPopoverArrowDirection = .any) -> PresentationStyle {
        return popover(from: .left(sourceView), permittedDirections: permittedDirections)
    }

    /// Present in a popover from the `barButtonItem` and given the `permittedDirections`.
    static func popover(from barButtonItem: UIBarButtonItem, permittedDirections: UIPopoverArrowDirection = .any) -> PresentationStyle {
        return popover(from: .right(barButtonItem), permittedDirections: permittedDirections)
    }

    /// Present in popover if iPad or modally if iPhone.
    static func popoverOrModal(from sourceView: UIView) -> PresentationStyle {
        if isIpad {
            return .popover(from: sourceView)
        } else {
            return .modal
        }
    }

    /// Present in popover if iPad or modally if iPhone.
    static func popoverOrModal(from barButtonItem: UIBarButtonItem, permittedDirections: UIPopoverArrowDirection = .any) -> PresentationStyle {
        if isIpad {
            return .popover(from: barButtonItem, permittedDirections: permittedDirections)
        } else {
            return .modal
        }
    }

    /// Present invisibly.
    static let invisible = PresentationStyle(name: "invisible") { _, _, _ in
        return (Future(), { Future() })
    }

    /// Present by embedding the view controller in `view`.
    /// - Parameter dynamicPreferredContentSize: Whether or not the child view controller should automatically update the parents preferredCOntentSize.
    static func embed(in view: UIView?, dynamicPreferredContentSize: Bool = true) -> PresentationStyle {
        return PresentationStyle(name: "embed") { vc, from, _ in
            let result = Future<()> { _ in
                let bag = DisposeBag()

                let parentView: ReadSignal<UIView> = view.map { ReadSignal($0) } ?? vc.signal(for: \.view).map { $0! }
                from.addChild(vc)

                var movedToParent = false
                bag += parentView.atOnce().onValueDisposePrevious { parentView in
                    parentView.hasWindowSignal.atOnce().filter { $0 }.onFirstValue { _ in
                        UIView.performWithoutAnimation { // prevents animation when the parent vc is modallly presented
                            vc.view.frame = parentView.bounds // So it has already the correct frame and avoid some resize animation on iOS 9..
                            parentView.embedView(vc.view)
                            vc.view.layoutIfNeeded()
                        }
                        if !movedToParent {
                            vc.didMove(toParent: from)
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
                vc.willMove(toParent: nil)
                vc.view.removeFromSuperview()
                vc.removeFromParent()
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

private extension PresentationStyle {
    static func popover(from source: Either<UIView, UIBarButtonItem>, permittedDirections: UIPopoverArrowDirection) -> PresentationStyle {
        return PresentationStyle(name: "popover") { viewcontroller, from, options in
            let vc = viewcontroller.embededInNavigationController(options)

            vc.modalPresentationStyle = .popover

            return from.modallyPresentQueued(vc, options: options) {
                let popover = vc.popoverPresentationController
                popover?.permittedArrowDirections = permittedDirections

                switch source {
                case .left(let view):
                    popover?.sourceView = view
                    popover?.sourceRect = view.bounds
                case .right(let item):
                    popover?.barButtonItem = item
                }

                UIApplication.shared.keyWindow?.endEditing(true)
                return Future { completion in
                    let bag = DisposeBag()

                    if let popover = vc.popoverPresentationController {
                        let delegate = PopoverPresentationControllerDelegate { completion(.failure(PresentError.dismissed)) }
                        popover.delegate = delegate
                        bag.hold(delegate)
                    } else {
                        bag += viewcontroller.installDismissButton().onValue { completion(.failure(PresentError.dismissed)) }
                    }

                    return bag
                }
            }
        }
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
