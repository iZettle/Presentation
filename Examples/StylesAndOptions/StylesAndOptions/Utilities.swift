//
//  Utilities.swift
//  StylesAndOptions
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

struct TapToDismiss { }

extension TapToDismiss: Presentable {
    public func materialize() -> (UIViewController, Future<()>) {
        let vc = UIViewController()
        let button = UIButton()
        button.setTitle("Tap To Dismiss", for: .normal)
        button.backgroundColor = .blue
        vc.view = button

        return (vc, Future<()> { completion in
            return button.onValue {
                completion(.success)
            }
        })
    }
}
