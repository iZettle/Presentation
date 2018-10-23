//
//  PresentableFlow.swift
//  Presentation
//
//  Created by Vasil Nunev on 2018-10-23.
//  Copyright © 2018 iZettle. All rights reserved.
//

import UIKit

public protocol PresentableFlow {
    associatedtype PresentableFlowResult

    func show(on viewController: UIViewController) -> PresentableFlowResult
}
