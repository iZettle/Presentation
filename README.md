<img src="https://github.com/iZettle/Presentation/blob/master/presentation-logo.png?raw=true" height="140px" />

[![Build Status](https://travis-ci.org/iZettle/Presentation.svg?branch=master)](https://travis-ci.org/iZettle/Presentation)
[![Platforms](https://img.shields.io/badge/platform-%20iOS%20-gray.svg)](https://img.shields.io/badge/platform-%20iOS%20-gray.svg)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

Presentation is an iOS Swift library for working with UI presentations in a more structured way with a focus on:

- Formalizing the driving of presentations from model to result.
- Introducing tools and patterns for improving separation of concerns.
- Providing conveniences for presenting view controllers and managing of their lifetime.

Even though Presentation is flexible it is also opinionated and has a preferred way of building presentations:

- Be explicit about model data and results. 
- Build and layout UIs programmatically.
- Use reactive programming for event handling.
- Prefer small reusable components and extensions to subclassing.

The Presentation framework builds heavily upon the [Flow framework](https://github.com/iZettle/Flow) to handle event handling, asynchronous flows, and lifetime management. 

## Example usage

```swift
// Declare the model and data needed to present the messages UI
struct Messages {
  var messages: ReadSignal<Message>
}

// Conform to Presentable and implement materialize to produce  
// a UIViewController and a Disposable for life-time management
extension Messages: Presentable {
  func materialize() -> (UIViewController, Disposable) { 
    // Setup viewController and views
    let viewController = UITableViewController()

    // Set up event handlers
    let bag = DisposeBag()
    bag += messages.atOnce().onValue { // update table view }
    
    return (viewController, bag)
  }
}   

/// Create an instance and present it
let messages = Messages(...)
presentingViewController.present(messages)
```

### Contents:

- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
    - [Presentable](#presentable)
    - [Presenting](#presenting)
    - [Customization](#customization)
    - [Presentation](#presentation)
    - [Type-erased Presentable](#type-erased-presentable)
    - [Alerts](#alerts)
    - [Master detail](#master-detail)
- [Field tested](#field-tested)

## Requirements

- Xcode `9.3+`
- Swift 4.1
- iOS `9.0+`

## Installation

#### [Carthage](https://github.com/Carthage/Carthage)

```shell
github "iZettle/Presentation" >= 1.0
```

#### [Cocoa Pods](https://github.com/CocoaPods/CocoaPods)

```ruby
platform :ios, '9.0'
use_frameworks!

target 'Your App Target' do
  pod 'PresentationFramework', '~> 1.0'
end
```

## Usage

Presentation is based on a few core types and methods:  

- **Presentable**: Materialize your presentation model into something to present and the result of this presentation.
- **present()**: View controller methods for presenting your presentables.
- **PresentationStyle**: The style of a presentation, such as `modal` or `popover`.
- **Presentation**: Wraps a presentable together with presentation parameters and actions.
- **AnyPresentable**: Type-erased `Presentable`.  

### Presentable

Presentation encourages you to declare a presentation-model up-front where all data is provided to set up, update and complete a presentation. 

```swift
struct Messages {
  var messages: ReadSignal<Message>
  var filter: (String?) -> ()
  var refresh: () -> Future<()>
}
```

You conform this model to the `Presentable` protocol to describe how to materialize the model into something to present and the result of this presentation:

```swift
extension Messages: Presentable {
  func materialize() -> (UIViewController, Disposable) { 
    // Setup view controller and views
    let viewController = UITableViewController()

    // Set up event handlers
    let bag = DisposeBag()
    bag += messages.atOnce().onValue { // update table view }
    
    return (viewController, bag)
  }
}   
```

The `Presentable` protocol is defined as:

```swift
public protocol Presentable {
  associatedtype Matter
  associatedtype Result

  func materialize() -> (Matter, Result)
}
```

Here `Matter` is typically a `UIViewController` or a sub-class of thereof, and the `Result` of the presentation is usually one of the three core types of [Flow](https://github.com/iZettle/Flow).

- ***Disposable*** - For presentations that do not complete by themselves. 
- ***Future<T>*** - For presentations that do complete once by themselves.
- ***Signal<T>*** - For presentations that signal completions without necessary being dismissed.

Returning a `Disposable` is common when someone external to the presentable is dismissing the presentation such as when presented in a tab bar or from a menu. This is true for our `Messages` model above.

But if the presentable will drive the completion such as when collecting some data in a form you typically return a `Future` instead: 

```swift
struct ComposeMessage { }

extension ComposeMessage: Presentable {
  func materialize() -> (UIViewController, Future<Message>) {
    // Setup view controller and views
    let viewController = UIViewController(...)
    viewController.view = ...

    return (viewController, Future { completion in
      // Setup event handlers
      let bag = DisposeBag()
      
      bag += postButton.onValue { 
        completion(.success(Message(...))
      }
      
      return bag
    })
  }
}
```

Even though our compose message model has no data we still define a type for it to be able to refer to it and conform it to `Presentable`. Here the returned future will complete with a composed message on success.

Finally, returning a `Signal` indicates that the presentation might signal a result several times, such as when being presented on a navigation stack, where signaling will push the next view controller, but we can still come back to the previous one. 

For example, `Messages` could potentially be updated to return a `Signal<Message>` instead, to indicate that details about the message should be shown:

```swift
extension Messages: Presentable {
  func materialize() -> (UIViewController, Signal<Message>) { ... }
}   
```

### Presenting 

Once you have conformed your presentation model to `Presentable` you can conveniently present it from another view controller:

```swift
let messages = Messages(...)
presentingController.present(messages)
```

Calling `present()` will return a future that can be used to abort a presentation:

```swift
let future = presentingController.present(messages)

future.cancel() // Abort and dismiss the presentation
```

It is also possible to present a presentable on a window to set it as the root controller:

```swift
bag += window.present(messages)
```

If the presentable returns a future or a signal, `present()` will return one as well allowing you to retreive the result: 

```swift
let compose = ComposeMessage(...)
presentingController.present(compose).onValue { message in
  // Called with a composed message on dismiss
}
```

### Customization

The `present()` methods takes three defaulted arguments, `style`, `options` and `configure`, that you can provide to customize a presentation:

```swift
controller.present(messages, style: .modal, options: [ ... ]) { vc, bag in
  // Customize view controller and use bag to add presentation activities 
}
```

#### Style

Presentation comes with several `PresentationStyle`s such as `default`, `modal`, `popover` and `embed`. But you can also extend it with your custom ones:

```swift
extension PresentationStyle {
  static let customStyle = PresentationStyle(name: "custom") { 
    viewController, presentingController, options in
      // Run and animate presentation and define how to dismiss  
      return (result, dismiss)
    }
}
```

#### Options

You can also provide options to customize the presentation. Presentation comes with several `PresentationOptions` such as `embedInNavigationController`, `restoreFirstResponder` and `showInMaster`. You can also add more options for your custom presentation styles:

```swift
extension PresentationOptions {
  static let customOption = PresentationOptions()
}  
```

#### Configure

Finally, you can optionally provide a configuration closure that will be called with the view controller that is just about to be presented together with a `DisposeBag` that will let you add activities that will be kept alive for the duration of the presentation:

```swift
controller.present(messages) { vc, bag in
  // Customize view controller and use bag to add presentation activities 
}
```

It is useful to add a dismiss button to dismiss a presentation and Presentation adds a convenience function for adding these to a presented view controller:

```swift
let done = UIBarButtonItem(...)
controller.present(messages, configure: dismiss(done))
```

### Presentation

The `Presentation` type bundles a presentable together with presentation parameters and actions to call once being presented or dismissed. A `Presentation` can be presented similarly as a `Presentable` but without any explicit presentation parameters:

```swift
let compose = Presentation(ComposeMessage(), style: ..., options: ..., configure: ...)

presentingController.present(compose)
```

By using `Presentation`s in our presentable's model data we will relieve it from the knowledge how to construct and present other presentables:

```swift
struct Messages {
  let messages: ReadSignal<[Message]>
  let composeMessage: Presentation<ComposeMessage>
}
```
 
Using presentations is a great way to decouple two UIs and removes the need to forward any model data needed to construct and present other presentations.  

So far we have shown how to define and materialize our presentables, but not how to initialize them. It is important to realize that the data needed to initialize a presentable is not necessary data that the presentable itself need to know about. To make this decoupling of initialization and presentation more explicit, it could be useful to separate these into separate files, and potentially separate modules as well. The initializer could, for example, be given access to resources not available from the presentable's own module.

```swift
extension Messages {
  init(messages: [Message]) {
    let messagesSignal = ReadWriteSignal(messages)
    self.messages = messagesSignal.readOnly()
    
    let compose = Presentation(ComposeMessage(), style: .modal)
    self.composeMessage = compose.onValue { message in
      messagesSignal.value.insert(message, at: 0)
    }
  }
}
```

Here we can see that a `Presentation` also allows adding actions and transformations to be called upon its presentation and dismissal. In this case, we will set up an action to be called once the compose presentation is being successfully dismissed with the newly composed message. The new message will just be prepended to our messagesSignal that will signal our `Messages` presentable to update its table view.

It is important to realize that the above initialization of `Messages` is just one of many potential implementations. In a more realistic example, we might include network requests and some kind of persistence store such as CoreData. But however we chose to implement this, it will not affect our presentable type and its materialize implementation. We might even have several initializers for different purposes such as production, unit-testing and sample apps. 

A useful way to view a presentable is as a recipe on how to present something. Having an instance of a presentable does not mean that any UI has yet been constructed. The user might never choose to compose a message, or might compose more than one. But we still just have one instance of the compose presentable.

### Type-erased `Presentable`

Sometimes it can be useful to anonymize a presentable, for example, to be able to pass different presentables interchangeable to an API. 

```swift
let anonymized = AnyPresentable(message) // AnyPresentable<UIViewController, Disposable>
```

As `AnyPresentable` is just a type-erased `Presentable` it can also be used with `Presentation`. You can, for example, use it to wrap some legacy view controller you do not feel the need to add a model for:

```swift
let presentation = DisposablePresentation {
  let vc = storyboard.instantiateViewController(...)
  let bag = DisposeBag()
  // setup vc and potential activities
  
  return (vc, bag)
}
```

Where `DisposablePresentation` is just a type alias for:

```swift
typealias DisposablePresentation = AnyPresentation<UIViewController, Disposable>
```

And AnyPresentation as is a type alias for:

```swift
typealias AnyPresentation<Context: UIViewController, Result> = Presentation<AnyPresentable<Context, Result>>
```

### Alerts

Presentation comes with a built in `Alert` presentable to make it more convenient  to work with alerts and action sheets:

```swift
let alert = Alert<Bool>(title: ..., message: ..., actions: 
  Action(title: "Yes") { true }
  Action(title: "No") { false }
  Action(title: "Cancel", style: .cancel) { throw CancelError() },
)

// Display as an alert
presentingController.present(alert).onValue { boolean in
  // Selected yes or no 
}.onError { error in
  // Did cancel
}

// Display as an action sheet
presentingController.present(alert, style: .sheet())
```

### Master-detail

Presentation also comes with some helper types to make it easier to work with master-detail UIs such as split view controllers:

- `KeepSelection`: Maintain a single selection at the time. 
- `MasterDetailSelection`: Extends `KeepSelection` to handle collapsable views. 
- `DualNavigationControllersSplitDelegate`: Coordination between navigation controllers.

## Field tested

Presentation was developed, evolved and field-tested over the course of several years, and is pervasively used in [iZettle](https://izettle.com)'s highly acclaimed point of sales app.
