//
//  ChooseOptions.swift
//  Example
//
//  Created by Nataliya Patsovska on 2018-06-12.
//  Copyright © 2018 iZettle. All rights reserved.
//

import Flow
import Presentation

struct NamedPresentationOptions {
    let name: String
    let value: PresentationOptions
}

struct ChoosePresentationOptions { }

extension PresentationOptions {
    static let navigationBarPreference = PresentationOptions()
    static let showAlertOnDidAttemptToDismiss = PresentationOptions()
}

extension PresentationOptions {
    static func namedOptionsDataSource() -> DataSource<NamedPresentationOptions> {
        let presentationOptions: [(String, PresentationOptions)] = [
            ("Default", .defaults),
            ("Embed In Navigation Controller", .embedInNavigationController),
            ("Dont Wait For Dismiss Animation", .dontWaitForDismissAnimation),
            ("Unanimated", .unanimated),
            ("Restore first responder", .restoreFirstResponder),

            ("Show In Master (for split v)", .showInMaster),
            ("Fail On Block (for modal/popover vc)", .failOnBlock),

            ("Tap Outside To Dismiss (for modal/sheet vc)", .tapOutsideToDismiss),

            ("Disable Push Pop Coalecing (for navigation vc)", .disablePushPopCoalecing),
            ("Auto Pop (for navigation vc)", .autoPop),
            ("Auto Pop Successors (for navigation vc)", .autoPopSuccessors),
            ("Auto Pop Self And Successors (for navigation vc)", .autoPopSelfAndSuccessors),
            ("NavigationBar visibility preference", .navigationBarPreference),
            ("Show alert on swipe down to dismiss", .showAlertOnDidAttemptToDismiss),
            ("Embed in navigation and swipe down to dismiss", [.showAlertOnDidAttemptToDismiss, embedInNavigationController]),
            ("Allow swipe to dismiss always", [.allowSwipeDismissAlways, .defaults])
        ]
        return DataSource(options: presentationOptions.map {
            NamedPresentationOptions(name: $0.0, value: $0.1)
        })
    }
}

extension ChoosePresentationOptions: Presentable {
    public func materialize() -> (UIViewController, Signal<PresentationOptions>) {
        let viewController = UITableViewController()
        viewController.title = "Presentation Options"

        let result = viewController.configure(dataSource: PresentationOptions.namedOptionsDataSource())

        return (viewController, result.map { $0.value })
    }
}

extension NamedPresentationOptions: CustomStringConvertible {
    public var description: String { return name }
}
