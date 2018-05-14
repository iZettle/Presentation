//
//  PresentableInterceptor.swift
//  Presentation
//
//  Created by Måns Bernhardt on 2017-04-26.
//  Copyright © 2017 iZettle. All rights reserved.
//

import Foundation
import Flow


extension Presentable {
    func interceptedMaterialize() -> (Matter, Result) {
        let (vc, result) = materialize()
        
        #if DEBUG
            if let i = presentableInterceptor, let r = i.intercept(self) {
                return (vc, r)
            }
        #endif
        
        return (vc, result)
    }
}

/// For unit-testing
#if DEBUG
    
var presentableInterceptor: PresentableInterceptor? = nil
    
protocol PresentableInterceptor {
    func intercept<P: Presentable>(_ p: P) -> P.Result?
}
    
#endif

