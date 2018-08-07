//
//  AppDelegate.swift
//  Example
//
//  Created by Nataliya Patsovska on 2018-06-05.
//  Copyright © 2018 iZettle. All rights reserved.
//

import UIKit
import Flow
import Presentation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let bag = DisposeBag()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        // Always show memory leaks alerts in examples
        UserDefaults.standard.set(true, forKey: enabledDisplayAlertOnMemoryLeaksKey)

        let window = UIWindow(frame: UIScreen.main.bounds)
        bag += window.present(AppFlow())

        return true
    }
}

