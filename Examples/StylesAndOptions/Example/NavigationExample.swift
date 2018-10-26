//
//  NavigationExample.swift
//  Example
//
//  Created by Mayur Deshmukh on 23/10/18.
//  Copyright © 2018 iZettle. All rights reserved.
//

import Foundation
import Presentation
import Flow

struct NavigationExample { }

struct TestNavigationBarHiding {

}

extension TestNavigationBarHiding: Presentable {
    func materialize() -> (UIViewController, Disposable) {
        let nc = UINavigationController()

        let bag = DisposeBag()
        bag += nc.present(Presentation(NavigationExample())).onValue {
            bag += nc.present(Presentation(NavigationExample(), options: PresentationOptions.prefersNavigationBarHidden(true))).onValue {
                bag += nc.present(Presentation(NavigationExample(), options: PresentationOptions.prefersNavigationBarHidden(false))).onValue {
                }
            }
        }
        return (nc, bag)
    }
}


extension NavigationExample: Presentable {
    public func materialize() -> (UIViewController, Signal<()>) {
        let vc = UIViewController()

        let button = UIButton()
        button.setTitle("Next", for: .normal)
        button.backgroundColor = .red
        vc.view = button

        return (vc, Signal { callback in
            return button.onValue {
                callback(())
            }
        })
    }
}
