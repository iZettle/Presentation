//
//  AppFlow.swift
//  Example
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
        let withDismiss = installDismiss(UIBarButtonItem(title: "Cancel"))

        let chooseOptions: () -> Future<PresentationOptions> = {
            let choosePresentationOptions = Presentation(ChoosePresentationOptions(), style: .modal, configure: withDismiss)
            return containerController.present(choosePresentationOptions).future
        }

        typealias ShowPresentationOrAlert = (PresentationStyle, PresentationOptions, UIViewController?, Alert<()>?) -> Future<()>
        let showDismissablePresentationOrAlert: ShowPresentationOrAlert = { style, options, preferredPresenter, alertToPresent in
            let presentation: EitherPresentation<TapToDismiss, Alert<()>>

            if options.contains(.navigationBarPreference) {
                return containerController.present(Presentation(TestNavigationBarHiding(), style: .modal)).toVoid()
            }

            if options.contains(.allowSwipeDismissAlways) {
                struct NavigationStack: Presentable {
                    func materialize() -> (UIViewController, Disposable) {
                        let (vc, _) = TapToDismiss().materialize()
                        vc.present(TapToDismiss())

                        return (vc, NilDisposer())
                    }
                }
                return containerController.present(NavigationStack(), style: style, options: options)
            }

            if let alertToPresent = alertToPresent {
                presentation = .right(Presentation(alertToPresent,
                                                   style: style,
                                                   options: options,
                                                   configure: withDismiss))
            } else {
                presentation = .left(Presentation(TapToDismiss(showAlertOnDidAttemptToDismiss: options.contains(.showAlertOnDidAttemptToDismiss)),
                                                  style: style,
                                                  options: options,
                                                  configure: style.name == "default" ? { _, _  in } : withDismiss))
            }
            return (preferredPresenter ?? containerController).present(presentation).toVoid()
        }

        let styleWithContext = containerController.present(ChooseStyle(), options: [.defaults, .showInMaster])

        bag += styleWithContext.onValueDisposePrevious { style, preferredPresenter, alertToPresent in
            return chooseOptions().onValue { options in
                bag += showDismissablePresentationOrAlert(style, options, preferredPresenter, alertToPresent).disposable
            }.disposable
        }

        return (containerController, bag)
    }
}
