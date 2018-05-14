//
//  MemoryUtils.swift
//  iZettlePresentation
//
//  Created by Emmanuel Garnier on 2017-10-02.
//  Copyright © 2017 iZettle. All rights reserved.
//

import UIKit
import Flow


public extension UIViewController {
    /// Whether to track and log memory leaks of presented view controllers, default to true
    var debugMemoryLeakTrackingEnabled: Bool {
        get { return associatedValue(forKey: &memoryLeakTrackingEnabledKey, initial: true) }
        set { setAssociatedValue(newValue, forKey: &memoryLeakTrackingEnabledKey) }
    }
}

/// UserDefaults key to boolean value to whether an alert should be presented in debug builds if a memory leak is discovered.
public let enabledDisplayAlertOnMemoryLeaksUserDefaultsKey = "enabledDisplayAlertOnMemoryLeaks"

extension UIViewController {
    func trackMemoryLeaks(_ vc: UIViewController, whenDisposed bag: DisposeBag) {
        guard vc.debugMemoryLeakTrackingEnabled else { return }
        
        let presentationDescription = self.presentationDescription
        let vcPresentationDescription = vc.presentationDescription
        
        vc.deallocSignal.future.onValue {
            log("\(vcPresentationDescription) was deallocated after presentation from \(presentationDescription)")
        }
        
        func onLeak() {
            log("WARNING \(vcPresentationDescription) was NOT deallocated after presentation from \(presentationDescription)")
            
            guard UserDefaults.standard.bool(forKey: enabledDisplayAlertOnMemoryLeaksUserDefaultsKey) else { return }
            
            #if DEBUG
                let alert = Alert<()>(title: "View controller not released after being dismissed", message: vcPresentationDescription, actions: Alert<()>.Action(title: "OK") {  })
                var presentingVC = UIApplication.shared.keyWindow?.rootViewController
                while let presentedVC = presentingVC?.presentedViewController { presentingVC = presentedVC }
                presentingVC?.present(alert)
            #endif
        }
        
        vc.trackMemoryLeak(whenDisposed: bag) { leakingVC in
            if let nc = leakingVC.navigationController {
                nc.deallocSignal.future.onValue { [weak leakingVC] in
                    guard let _ = leakingVC else { return }
                    onLeak()
                }
                return
            }
            
            onLeak()
        }
    }
}

final class Weak<T> where T: AnyObject {
    private(set) weak var value: T?
    init(_ value: T) { self.value = value }
}

extension NSObject {
    var deallocSignal: Signal<()> {
        return associatedValue(forKey: &trackerKey, initial: DeallocTracker()).providedSignal
    }
}

extension NSObjectProtocol {
    func trackMemoryLeak(whenDisposed bag: DisposeBag, after: TimeInterval = 2, _ onLeak: @escaping (Self) -> () = { o in assertionFailure("Object Not Deallocated \(o)") }) {
        bag += { [weak self] in
            Scheduler.main.async(after: after) {
                guard let strongSelf = self else { return }
                onLeak(strongSelf)
            }
        }
    }
}

private final class DeallocTracker: SignalProvider {
    let callbacker = Callbacker<()>()
    
    var providedSignal: Signal<()> {
        return Signal(callbacker: callbacker)
    }
    
    deinit { callbacker.callAll(with: ()) }
}

private var trackerKey = false
private var memoryLeakTrackingEnabledKey = false

