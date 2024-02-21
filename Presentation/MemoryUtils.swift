//
//  MemoryUtils.swift
//  iZettlePresentation
//
//  Created by Emmanuel Garnier on 2017-10-02.
//  Copyright © 2017 PayPal Inc. All rights reserved.
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
public let enabledDisplayAlertOnMemoryLeaksKey = "enabledDisplayAlertOnMemoryLeaks"

#if DEBUG
    extension UIViewController {
        func trackMemoryLeaks(_ vc: UIViewController, whenDisposed bag: DisposeBag) {
            guard vc.debugMemoryLeakTrackingEnabled else { return }

            let presentationDescription = self.presentationDescription
            let vcPresentationDescription = vc.presentationDescription

            vc.deallocSignal.future.onValue {
                log(.didDeallocate(.init(vcPresentationDescription), from: .init(presentationDescription)))
            }

            func onLeak() {
                log(.didLeak(.init(vcPresentationDescription), from: .init(presentationDescription)))
                let memoryLeak = UIVCMemoryLeak(name: self.presentationTitle)
                UIVCMemoryLeakFileWriter().write(memoryLeak: memoryLeak)

                guard UserDefaults.standard.bool(forKey: enabledDisplayAlertOnMemoryLeaksKey) else { return }

                let alert = Alert<()>(title: "View controller not released after being dismissed", message: vcPresentationDescription, actions: Alert<()>.Action(title: "OK") {  })
                var presentingVC = UIApplication.shared.keyWindow?.rootViewController
                while let presentedVC = presentingVC?.presentedViewController { presentingVC = presentedVC }
                presentingVC?.present(alert)
            }

            vc.trackMemoryLeak(whenDisposed: bag) { leakingVC in
                if let nc = leakingVC.navigationController {
                    nc.deallocSignal.future.onValue { [weak leakingVC] in
                        guard leakingVC != nil else { return }
                        onLeak()
                    }
                    return
                }

                onLeak()
            }
        }
    }
#endif

final class Weak<T> where T: AnyObject {
    private(set) weak var value: T?
    init(_ value: T) { self.value = value }
}

extension NSObjectProtocol {
    func trackMemoryLeak(whenDisposed bag: DisposeBag, after: TimeInterval = 2, _ onLeak: @escaping (Self) -> () = { object in assertionFailure("Object Not Deallocated \(object)") }) {
        bag += { [weak self] in
            Scheduler.main.async(after: after) {
                guard let strongSelf = self else { return }
                onLeak(strongSelf)
            }
        }
    }
}

private var memoryLeakTrackingEnabledKey = false

private struct UIVCMemoryLeak {

    internal let name: String

    internal func jsonRepresentation() -> [String: Any] {
        return [
            "name": self.name
        ]
    }
}

private class UIVCMemoryLeakFileWriter {

    private let mlDirName = "presentation-memory-leaks"
    private let tmpDir = "/tmp"

    internal func write(memoryLeak: UIVCMemoryLeak) {
        let mlDirPath = self.tmpDir.appending("/\(self.mlDirName)")
        self.createMemoryLeaksDir(pathToDir: mlDirPath)
        let fileName = UUID().uuidString + ".json"
        let filePath = mlDirPath.appending("/\(fileName)")
        let fileURL = URL(fileURLWithPath: filePath)
        let jsonWriter = JSONWriter(jsonPath: fileURL)
        do {
            try jsonWriter.writeJSON(memoryLeak.jsonRepresentation())
        } catch {
            print("| Presentation >>> cannot write JSON file for memory leak ✗")
        }
    }

    private func createMemoryLeaksDir(pathToDir: String) {
        do {
            let mlDirURL = URL(
                fileURLWithPath: pathToDir
            )
            try FileManager.default.createDirectory(
                at: mlDirURL,
                withIntermediateDirectories: true
            )
        } catch {
            print("| Presentation >>> cannot create dir ✗ : \(self.mlDirName)")
            print(error)
        }
    }
}

private class JSONWriter {

    private var jsonPath: URL

    internal init(jsonPath: URL) {
        self.jsonPath = jsonPath
    }

    internal func writeJSON(_ json: [String: Any]) throws {
        let fileName =  self.jsonPath.lastPathComponent
        let jsonData = try JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted]
        )
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("| Presentation >>> write ✗ : \(fileName)")
            throw JSONWriterError.cannotWriteGivenFileAsJSON
        }
        try jsonString.write(
            to: self.jsonPath,
            atomically: true,
            encoding: .utf8
        )
        print("| Presentation >>> write ✓ : \(fileName)")
    }
}

private enum JSONWriterError: Error {
    case cannotWriteGivenFileAsJSON
}
