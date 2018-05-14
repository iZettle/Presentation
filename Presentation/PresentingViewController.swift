//
//  PresentingViewController.swift
//  Presentation
//
//  Created by Måns Bernhardt on 2016-01-27.
//  Copyright © 2016 iZettle. All rights reserved.
//

import UIKit
import Flow


/// Conforming types can customize the presentation of view controllers on `self`.
/// Used by the `default` `PresentationStyle` to forward the handling of a presentation.
/// Typically conformed by coordination view controllers such as `UINavitgationController` and `UISplitViewController`.
public protocol PresentingViewController {
    /// Result will complete the presentation when completing, typically with an error such as PresentError.dismissed.
    /// `dismisser` will start dismissing the presentation when called and the returned future will complete when the dismiss is done.
    typealias Result = (result: Future<()>, dismisser: () -> Future<()>)
    func present(_ viewController: UIViewController, options: PresentationOptions) -> Result
}

