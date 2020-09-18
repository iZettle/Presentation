//
//  Alert.swift
//  Presentation
//
//  Created by Måns Bernhardt on 2016-03-01.
//  Copyright © 2016 PayPal Inc. All rights reserved.
//

import UIKit
import Flow

/// A presentable of an alert or an action sheet.
///
///     let deleteAction = Alert.Action(title: "Delete", style: .destructive) { /// delete }
///     let alert = Alert(title: ..., actions: deleteAction)
///     vc.present(alert)
public struct Alert<Value> {
    /// An action to be displayed
    public struct Action {
        public var title: String
        public var style: UIAlertAction.Style

        /// A closure that produces the result of this action. It accepts an array of the current values of the action's fields as its parameter and returns a result value
        public var action: ([String]) throws -> Value

        /// A predicate whether this action should be enabled for given field values
        public var enabledPredicate: ([String]) -> Bool
    }

    public struct Field {
        /// Initial value
        public var initial: String

        /// Customization point to configure the text field before being presented.
        public var configure: (UITextField) -> ()

        public init(initial: String = "", configure: @escaping (UITextField) -> () = { _ in }) {
            self.initial = initial
            self.configure = configure
        }
    }

    public var title: String?
    public var message: String?
    public var actions: [Action]
    public var fields: [Field]
    public var tintColor: UIColor?
}

public extension UIColor {
    /// Customization point to set the default alert tint color.
    @nonobjc static var defaultAlertTintColor: UIColor?
}

public extension Alert {
    /// Creates a new alert with `actions` and an optional `title`, `message` and `fields`.
    init(title: String? = nil, message: String? = nil, tintColor: UIColor? = .defaultAlertTintColor, fields: [Field] = [], actions: [Action]) {
        self.title = title
        self.message = message
        self.tintColor = tintColor
        self.actions = actions
        self.fields = fields
    }

    /// Creates a new alert with `actions` and an optional `title`, `message` and `fields`.
    init(title: String? = nil, message: String? = nil, tintColor: UIColor? = .defaultAlertTintColor, fields: [Field] = [], actions: Action...) {
        self.init(title: title, message: message, tintColor: tintColor, fields: fields, actions: actions)
    }
}

public extension Alert.Action {
    init(title: String, style: UIAlertAction.Style = .default, enabledPredicate: @escaping ([String]) -> Bool = { _ in true }, action: @escaping ([String]) throws -> Value) {
        self.title = title
        self.style = style
        self.action = action
        self.enabledPredicate = enabledPredicate
    }

    init(title: String, style: UIAlertAction.Style = .default, action: @escaping () throws -> Value) {
        self.init(title: title, style: style, action: { (_: [String]) in try action() })
    }
}

public extension PresentationStyle {
    /// Present using an action sheet from the `sourceView` and `sourceRect`
    /// - Note: Only useful together with `UIAlertController` such as `Alert`
    static func sheet(from sourceView: UIView? = nil, rect sourceRect: CGRect? = nil) -> PresentationStyle {
        return PresentationStyle(name: "sheet") { vc, from, options in
            guard var vc = vc as? UIAlertController else {
                fatalError("presented view controller must be an UIAlertController to be presented as a action sheet")
            }

            let bag = DisposeBag()
            if let createSheet: () -> (UIAlertController, Disposable) = vc.associatedValue(forKey: &createSheetKey) {
                var disposer: Disposable
                (vc, disposer) = createSheet()
                bag += disposer
            }

            if let presenter = vc.popoverPresentationController {
                presenter.sourceView = sourceView ?? from.view

                if let rect = sourceRect {
                    presenter.sourceRect = rect
                } else {
                    bag += presenter.sourceView?.signal(for: \.bounds).atOnce().onValue { [weak presenter] bounds in
                        presenter?.sourceRect = CGRect(x: floor(bounds.width / 2), y: floor(bounds.height / 2), width: 1, height: 1)
                    }
                }
            }

            let (present, dismiss) = modal.present(vc, from: from, options: options)

            return (present.always(bag.dispose), dismiss)
        }
    }
}

extension Alert: Presentable {
    public func materialize() -> (UIViewController, Future<Value>) {
        // A bunch of tricks to be able to convert an UIAlertController to a sheet but still make sure all futures etc are transferred correctly (this is because the decision whether to display as alert of sheet is decided by a style at a later stage).
        var completion: (Flow.Result<Value>) -> () = { _ in fatalError() }
        let bag = DisposeBag()
        func createSheet() -> (UIAlertController, Disposable) {
            bag.dispose()
            let (vc, future) = self.materialize(for: .actionSheet)
            return (vc, future.onResult(completion).disposable)
        }

        let (vc, future) = materialize(for: .alert)
        bag += future.onResult {
            completion($0)
        }

        vc.setAssociatedValue(createSheet, forKey: &createSheetKey)
        return (vc, Future { futureCompletion in
            completion = futureCompletion
            return NilDisposer()
        })
    }
}

private var createSheetKey = false

private extension Alert {
    func materialize(for preferredStyle: UIAlertController.Style) -> (UIAlertController, Future<Value>) {
        let vc = UIAlertController(title: title, message: message, preferredStyle: preferredStyle)
        vc.accessibilityLabel = title
        vc.message = message
        vc.preferredPresentationStyle = .modal

        defer { // Make sure to set after we added the actions.
            if #available(iOS 10.0, *) {
                vc.view.tintColor = tintColor
            } else {
                DispatchQueue.main.async { // on iOS 9, tint color is not set properly if set before the vc is presented
                    vc.view.tintColor = self.tintColor
                }
            }
        }

        vc.debugPresentationArguments["title"] = title
        vc.debugPresentationArguments["message"] = message

        return (vc, Future { completion in
            let bag = DisposeBag()
            let fields = ReadWriteSignal(self.fields.map { $0.initial })

            for (i, field) in self.fields.enumerated() {
                vc.addTextField { textField in
                    field.configure(textField)
                    textField.text = field.initial
                    bag += textField.bindTo { fields.value[i] = $0 }
                }
            }

            for action in self.actions {
                let actionSignal = vc.addActionWithTitle(action.title, style: action.style)
                let actionBag = DisposeBag()
                bag += actionBag
                bag += fields.atOnce().map { action.enabledPredicate($0) }.onValue { enabled in
                    actionBag.dispose()
                    guard enabled else { return }
                    actionBag += actionSignal.onValue {
                        do {
                            completion(.success(try action.action(fields.value)))
                        } catch {
                            completion(.failure(error))
                        }
                    }
                }
            }

            return bag
        })
    }
}

private extension UIAlertAction {
    convenience init(title: String, style: UIAlertAction.Style = .default, actionHandler: ((UIAlertAction) -> Void)? = nil) {
        self.init(title: title, style: style, handler: actionHandler)
        // No accessibilityIdentifier avaialble on UIAlertAction, so we only set the localized accessibilityLabel instead
        accessibilityLabel = title
    }
}

private extension UIAlertController {
    func addActionWithTitle(_ title: String, style: UIAlertAction.Style = .default) -> Signal<()> {
        let callbacker = Callbacker<()>()
        let action = UIAlertAction(title: title, style: style) { _ in callbacker.callAll(with: ()) }

        action.isEnabled = false
        addAction(action)

        return Signal<()> { callback in
            let bag = DisposeBag()
            bag += callbacker.addCallback(callback)
            action.isEnabled = true
            bag += {
                action.isEnabled = !callbacker.isEmpty
            }
            return bag
        }
    }
}
