//
//  UIViewController+Signals.swift
//  Presentation
//
//  Created by João D. Moreira on 2018-11-02.
//  Copyright © 2018 iZettle. All rights reserved.
//

import Foundation
import Flow
import UIKit

public extension UIViewController {
    var viewDidLoadSignal: Signal<UIView> {
        return signal(for: #selector(UIViewController.viewDidLoad))
    }

    var viewWillAppearSignal: Signal<UIView> {
        return signal(for: #selector(UIViewController.viewWillAppear(_:)))
    }

    var viewDidAppearSignal: Signal<UIView> {
        return signal(for: #selector(UIViewController.viewDidAppear(_:)))
    }

    var viewWillDisappearSignal: Signal<UIView> {
        return signal(for: #selector(UIViewController.viewWillDisappear(_:)))
    }
    var viewDidDisappearSignal: Signal<UIView> {
        return signal(for: #selector(UIViewController.viewDidDisappear(_:)))
    }

    var viewWillLayoutSubviewsSignal: Signal<UIView> {
        return signal(for: #selector(UIViewController.viewWillLayoutSubviews))
    }

    var viewDidLayoutSubviewsSignal: Signal<UIView> {
        return signal(for: #selector(UIViewController.viewDidLayoutSubviews))
    }

    private func signal(`for` selector: Selector) -> Signal<UIView> {
        return Signal(callbacker: callbacker)
            .filter(predicate: { return $0 == selector })
            .map { _ in return self.view }
    }
}

/// The callbacker used by the swizzled implementations
private var callbackerKey = false
private extension UIViewController {
    var callbacker: Callbacker<Selector> {
        let _ = UIViewController.runOnce
        return associatedValue(forKey: &callbackerKey, initial: Callbacker<Selector>())
    }
}

/// Swizzled method implementations
private extension UIViewController {
    @objc func _swizzled_viewDidLoad() {
        self._swizzled_viewDidLoad()
        callbacker.callAll(with: #selector(UIViewController.viewDidLoad))
    }

    @objc func _swizzled_viewWillAppear(_ animated: Bool) {
        self._swizzled_viewDidAppear(animated)
        callbacker.callAll(with: #selector(UIViewController.viewWillAppear(_:)))
    }

    @objc func _swizzled_viewDidAppear(_ animated: Bool) {
        self._swizzled_viewDidAppear(animated)
        callbacker.callAll(with: #selector(UIViewController.viewDidAppear(_:)))
    }

    @objc func _swizzled_viewWillDisappear(_ animated: Bool) {
        self._swizzled_viewWillDisappear(animated)
        callbacker.callAll(with: #selector(UIViewController.viewWillDisappear(_:)))
    }

    @objc func _swizzled_viewDidDisappear(_ animated: Bool) {
        self._swizzled_viewDidDisappear(animated)
        callbacker.callAll(with: #selector(UIViewController.viewDidDisappear(_:)))
    }

    @objc func _swizzled_viewWillLayoutSubviews() {
        self._swizzled_viewWillLayoutSubviews()
        callbacker.callAll(with: #selector(UIViewController.viewWillLayoutSubviews))
    }

    @objc func _swizzled_viewDidLayoutSubviews() {
        self._swizzled_viewDidLayoutSubviews()
        callbacker.callAll(with: #selector(UIViewController.viewDidLayoutSubviews))
    }
}


/// Swizzling of all UIViewController lifecycle methods
extension UIViewController: Swizzable { }
extension UIViewController {
    static let runOnce: Void = {
        let swizzle = UIViewController.swizzle
        swizzle(#selector(UIViewController.viewDidLoad), #selector(UIViewController._swizzled_viewDidLoad))
        swizzle(#selector(UIViewController.viewWillAppear(_:)), #selector(UIViewController._swizzled_viewWillAppear(_:)))
        swizzle(#selector(UIViewController.viewDidAppear(_:)), #selector(UIViewController._swizzled_viewDidAppear(_:)))
        swizzle(#selector(UIViewController.viewWillDisappear(_:)), #selector(UIViewController._swizzled_viewWillDisappear(_:)))
        swizzle(#selector(UIViewController.viewDidDisappear(_:)), #selector(UIViewController._swizzled_viewDidDisappear(_:)))
        swizzle(#selector(UIViewController.viewWillLayoutSubviews), #selector(UIViewController._swizzled_viewWillLayoutSubviews))
        swizzle(#selector(UIViewController.viewDidLayoutSubviews), #selector(UIViewController._swizzled_viewDidLayoutSubviews))
    }()
}

/// Helper protocol for swizzling
protocol Swizzable: AnyObject { }

extension Swizzable {
    static func swizzle(_ originalSel: Selector, _ swapSel: Selector) {
        let original = class_getInstanceMethod(Self.self, originalSel)
        let new = class_getInstanceMethod(Self.self, swapSel)
        method_exchangeImplementations(original!, new!)
    }
}
