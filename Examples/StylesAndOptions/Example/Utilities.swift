//
//  Utilities.swift
//  Example
//
//  Created by Nataliya Patsovska on 2018-06-13.
//  Copyright © 2018 iZettle. All rights reserved.
//

import UIKit
import Flow
import Presentation

extension UIBarButtonItem {
    convenience init(title: String) {
        self.init()
        self.title = title
    }
}

struct TapToDismiss {
    let showAlertOnDidAttemptToDismiss: Bool

    init(showAlertOnDidAttemptToDismiss: Bool = false) {
        self.showAlertOnDidAttemptToDismiss = showAlertOnDidAttemptToDismiss
    }
}

extension TapToDismiss: Presentable {
    public func materialize() -> (UIViewController, Future<()>) {
        let vc = UIViewController()
        if #available(iOS 13.0, *) {
            #if compiler(>=5.1)
            vc.isModalInPresentation = showAlertOnDidAttemptToDismiss
            #endif
        }
        let button = UIButton()
        button.setTitle("Tap To Dismiss", for: .normal)
        button.backgroundColor = .blue
        vc.view = button

        return (vc, Future<()> { completion in
            let bag = DisposeBag()
            if #available(iOS 13.0, *) {
                let delegate = CustomAdaptivePresentationDelegate()
                bag.hold(delegate)

                vc.customAdaptivePresentationDelegate = delegate
                bag += delegate.didAttemptToDismissSignal.onValue { _ in
                    let alertAction = Alert<()>.Action(title: "OK", action: { })
                    vc.present(Alert(message: "Test alert", actions: [alertAction]))
                }
            }
            bag += button.onValue {
                completion(.success)
            }
            return bag
        })
    }
}
