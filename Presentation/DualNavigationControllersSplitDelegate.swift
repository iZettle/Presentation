//
//  DualNavigationControllersSplitDelegate.swift
//  Presentation
//
//  Created by Måns Bernhardt on 2016-01-27.
//  Copyright © 2016 iZettle. All rights reserved.
//

import UIKit
import Flow


/// A split controller delegate (`UISplitViewControllerDelegate`), that manages navigation controllers for the master and detail view,
/// as well as moving view controllers between these while expanding or collapsing.
open class DualNavigationControllersSplitDelegate: NSObject, UISplitViewControllerDelegate {
    private let isCollapsedProperty = ReadWriteSignal(true)
    private var detailBag: Disposable? = nil

    /// Customization point for construction of the navigation controllers managed by `self`
    public var makeNavigationController = customNavigationController

    /// Customization point for whether the detail view should be hidden and disposed of when collapsed.
    public var hideDetailWhenCollapsing: () -> Bool = { return false }

    public let presentDetail = Delegate<UISplitViewController, Disposable>()

    /// Returns a signal that will signal when collapsing or expanding
    public var isCollapsedSignal: ReadSignal<Bool> {
        return isCollapsedProperty.readOnly()
    }

    internal func makeMasterNavigationController(_ splitController: UISplitViewController) -> UINavigationController {
        let nc = makeNavigationController(.showInMaster)
        return nc
    }

    internal func makeDetailNavigationController(_ splitController: UISplitViewController) -> UINavigationController {
        let nc = makeNavigationController([])
        return nc
    }

    open func targetDisplayModeForAction(in svc: UISplitViewController) -> UISplitViewControllerDisplayMode {
        isCollapsedProperty.value = svc.isViewLoaded && svc.view.window != nil ? svc.isCollapsed : true
        
        if svc.viewControllers.isEmpty {
            svc.viewControllers.append(makeMasterNavigationController(svc))
        }
        
        if svc.viewControllers.count == 1 && !svc.isCollapsed {
            let nc = makeDetailNavigationController(svc)
            svc.viewControllers.append(nc)
            detailBag = presentDetail.call(svc)
        }
        
        return .automatic
    }
    
    open func primaryViewController(forCollapsing splitViewController: UISplitViewController) -> UIViewController? {
        return nil
    }
    
    open func primaryViewController(forExpanding splitViewController: UISplitViewController) -> UIViewController? {
        return nil
    }
    
    open func splitViewController(_ svc: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        guard let primary = primaryViewController as? UINavigationController, let secondary = secondaryViewController as? UINavigationController else {
            detailBag?.dispose()
            return false
        }
        
        if hideDetailWhenCollapsing() {
            detailBag?.dispose()
        } else {
            if let top = primary.topViewController, let item = customNavigationBackButtonWithTitle(top.title ?? "") {
                top.navigationItem.backBarButtonItem = item
            }
            primary.transferViewControllers(from: secondary)
        }
        
        isCollapsedProperty.value = true

        return true
    }
    
    open func splitViewController(_ svc: UISplitViewController, separateSecondaryFrom primaryViewController: UIViewController) -> UIViewController? {
        guard let primary = primaryViewController as? UINavigationController else { return nil }
        guard svc.viewControllers.count < 2 else { return svc.viewControllers[1] }
        
        let masters = primary.viewControllers.filter { $0.wasPresentedInMaster }
        let vcs = primary.viewControllers.filter { !$0.wasPresentedInMaster }
        
        // Disable delegate while popping to root to avoid triggering pop-signal
        let delegate = primary.delegate
        primary.delegate = nil
        primary.viewControllers = masters
        primary.delegate = delegate
        
        let nc = makeDetailNavigationController(svc)
        if vcs.isEmpty {
            svc.viewControllers.append(nc)
            detailBag = presentDetail.call(svc)
        } else {
            nc.viewControllers = Array(vcs)
        }
        
        isCollapsedProperty.value = true
        
        return nc
    }
}

public extension UISplitViewController {
    /// Creates and returns a new split delegate that will be set as `self`'s delegate until `bag` is disposed.
    func setupSplitDelegate(ownedBy bag: DisposeBag) -> DualNavigationControllersSplitDelegate {
        let d = DualNavigationControllersSplitDelegate()
        delegate = d
        bag += {
            _ = d
            self.delegate = nil
        }
        return d
    }
}

