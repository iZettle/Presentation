//
//  PresentationEvent.swift
//  PresentationFramework
//
//  Created by Nataliya Patsovska on 2019-05-24.
//

import Foundation
import Flow

/// Events that can be handled by the provided `presentablePresentationEventHandler`
public enum PresentationEvent {
    /// Sent when a presentation is blocked by another presentation and will be enqueued for later presentation
    case willEnqueue(PresentableIdentifier, from: PresentableIdentifier)
    /// Sent when a presentation is unblocked and will be dequeued for presentation
    case willDequeue(PresentableIdentifier, from: PresentableIdentifier)
    /// Sent just before a presentation is presented
    case willPresent(PresentableIdentifier, from: PresentableIdentifier, styleName: String)
    /// Sent when a presentation was cancelled and is about to be dismissed
    case didCancel(PresentableIdentifier, from: PresentableIdentifier)
    /// Sent when a presentation is dismissed with a type-erased result of the presentation
    case didDismiss(PresentableIdentifier, from: PresentableIdentifier, result: Result<Any>)

    #if DEBUG
    case didDeallocate(PresentableIdentifier, from: PresentableIdentifier)
    case didLeak(PresentableIdentifier, from: PresentableIdentifier)
    #endif
}

/// Can be implemented by a Presentable to provide a custom identifier. Defaults to a string representation of the type of the presentable
public protocol PresentableIdentifierExpressible {
    var presentableIdentifier: PresentableIdentifier { get }
}

public struct PresentableIdentifier: ExpressibleByStringLiteral & Equatable & Hashable {
    public let value: String
    public init(_ value: String) { self.value = value }
    public init(stringLiteral value: String) { self.init(value) }
}

/// Customization point for presentation logging. Defaults to using `print()`
public var presentableLogPresentation: (_ message: @escaping @autoclosure () -> String, _ data: @escaping @autoclosure () -> String?, _ file: String, _ function: String, _ line: Int) -> () = { (message: () -> String, data: () -> String?, file, function, line) in
    print("\(file): \(function)(\(line)) - \(message()), data: \(data() ?? "")")
}

/// Customization point for handing presentation events. Defaults to `presentableLogPresentation` with details for each event type
public var presentablePresentationEventHandler: (_ event: @escaping @autoclosure () -> PresentationEvent, _ file: String, _ function: String, _ line: Int) -> () = { (event: () -> PresentationEvent, file, function, line) in
    let presentationEvent = event()
    let message: String
    var data: String?

    switch presentationEvent {
    case let .willEnqueue(presentableId, context):
        message = "\(context) will enqueue modal presentation of \(presentableId)"
    case let .willDequeue(presentableId, context):
        message = "\(context) will dequeue modal presentation of \(presentableId)"
    case let .willPresent(presentableId, context, styleName):
        message = "\(context) will '\(styleName)' present: \(presentableId)"
    case let .didCancel(presentableId, context):
        message = "\(context) did cancel presentation of: \(presentableId)"
    case let .didDismiss(presentableId, context, result):
        switch result {
        case .success(let result):
            message = "\(context) did end presentation of: \(presentableId)"
            data = "\(result)"
        case .failure(let error):
            message = "\(context) did end presentation of: \(presentableId)"
            data = "\(error)"
        }
    #if DEBUG
    case let .didDeallocate(presentableId, context):
        message = "\(presentableId) was deallocated after presentation from \(context)"
    case let .didLeak(presentableId, context):
        message = "WARNING \(presentableId) was NOT deallocated after presentation from \(context)"
    #endif
    }

    presentableLogPresentation(message, data, file, function, line)
}

internal func log(_ event: @escaping @autoclosure () -> PresentationEvent, file: String = #file, function: String = #function, line: Int = #line) {
    presentablePresentationEventHandler(event(), file, function, line)
}
