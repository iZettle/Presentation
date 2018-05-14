//
//  UISplitViewController+Presenting.swift
//  Presentation
//
//  Created by Måns Bernhardt on 2016-01-27.
//  Copyright © 2016 iZettle. All rights reserved.
//

import UIKit
import Flow


extension UISplitViewController: PresentingViewController {
    public func present(_ vc: UIViewController, options: PresentationOptions) -> PresentingViewController.Result {
        let presenter: PresentingViewController
        vc.setAssociatedValue(options.contains(.showInMaster), forKey: &isPresentedInMasterKey)
        
        switch (options.contains(.showInMaster), isCollapsed, viewControllers.first as? PresentingViewController, viewControllers.dropFirst().first as? PresentingViewController, options.contains(.embedInNavigationController)) {
            
        // (showInMaster, collapsed, primaryNC?, detailnC?, embeddInNc)
        case (false, true, let primary?, _, _):
            // If collapsed, let's check if there is a master vc to be push on
            if let primary = primary as? UINavigationController, primary.viewControllers.isEmpty {
                // if pushing a detail but no master yet, let's dismiss right away (This can happen when a detail is )
                return (Future(error: PresentError.dismissed), { Future() })
            }
            presenter = primary
        case (false, false, _, let detail?, _):
            presenter = detail
        case (false, false, _, nil, true):
            let nc: UINavigationController
            if let dual = delegate as? DualNavigationControllersSplitDelegate {
                nc = dual.makeDetailNavigationController(self)
            } else {
                nc = customNavigationController([])
            }
            presenter = nc
            viewControllers = [ viewControllers[0], nc ]
            //        case (true, false, _, nil, false):
        //            viewControllers = [ viewControllers[0], vc ]
        case (true, _, let primary?, _, _):
            presenter = primary
        case (true, _, nil, _, true):
            let nc: UINavigationController
            if let dual = delegate as? DualNavigationControllersSplitDelegate {
                nc = dual.makeMasterNavigationController(self)
            } else {
                nc = customNavigationController(.showInMaster)
            }
            presenter = nc
            viewControllers = [ nc ] + viewControllers.dropFirst()
        default:
            fatalError("Not supported")
        }
        
        return presenter.present(vc, options: options)
    }
}

extension UIViewController {
    var wasPresentedInMaster: Bool {
        return associatedValue(forKey: &isPresentedInMasterKey) ?? false
    }
}

private var isPresentedInMasterKey = false

