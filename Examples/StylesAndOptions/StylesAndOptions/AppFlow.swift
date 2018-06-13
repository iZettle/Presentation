//
//  AppFlow.swift
//  StylesAndOptions
//
//  Created by Nataliya Patsovska on 2018-06-05.
//  Copyright © 2018 iZettle. All rights reserved.
//

import UIKit
import Foundation
import Flow
import Presentation

enum ContainerType: String {
    case navigationController = "UseNavigationContainer"
    case splitViewController = "UseSplitViewContainer"
}

struct AppFlow {
    let containerType: ContainerType

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(ContainerType.splitViewController.rawValue) {
            containerType = .splitViewController
        } else {
            containerType = .navigationController
        }
    }
}

private extension AppFlow {
    func createContainer() -> UIViewController {

        switch containerType {
        case .splitViewController:
            let split = UISplitViewController()
            split.preferredDisplayMode = UIDevice.current.userInterfaceIdiom == .pad ? .allVisible : .automatic
            return split
        case .navigationController:
            return UINavigationController()
        }
    }
}

extension AppFlow: Presentable {
    public func materialize() -> (UIViewController, Disposable) {
        let bag = DisposeBag()

        let containerController = createContainer()
        let installDismiss = dismiss(UIBarButtonItem(title: "Cancel"))

        bag += containerController
            .present(ChooseStyle(), options: [.defaults, .showInMaster])
            .onValue { style, preferredPresenter, alertToPresent in

                containerController
                    .present(Presentation(ChoosePresentationOptions(), style: .modal, options: [.defaults, .showInMaster], configure: installDismiss)).future
                    .onValue { options in
                        let presentation: EitherPresentation<TapToDismiss, Alert<()>>
                        if let alertToPresent = alertToPresent {
                            presentation = .right(Presentation(alertToPresent,
                                                               style: style,
                                                               options: options,
                                                               configure: installDismiss))
                        } else {
                            presentation = .left(Presentation(TapToDismiss(),
                                                              style: style,
                                                              options: options,
                                                              configure: style.name == "default" ? { _,_  in } : installDismiss))
                        }
                        (preferredPresenter ?? containerController).present(presentation)
                }
        }
        return (containerController, bag)
    }
}
