# 1.13.0
- [Change] Move to Flow version 1.8.4
- [Bugfix] Fix compile time error in `public extension SignalProvider where Value: Collection {` for swift 5.2
- [Change] Remove `noTrailingClosure: () = ()` from `init<Result>` for  `Presentation` to avoid `Ambiguous use of 'init' for Signals` compile time errors on call site

# 1.12.0
- [Addition] Make swipe-to-dismiss blockable through protocol conformance.

# 1.11.0
- [Addition] Extracted the modal dismiss setup to a separate function, to be able to supply a custom presentation controller if needed.

# 1.10.0
- [Addition] Make it possible to embed a Presentable wrapped in a navigation controller within another view. 

# 1.9.2
- [Bug fix] View controller's modal presentation preferences not used when it's embedded in a navigation controller during presentation.

# 1.9.1
- [Bug fix] Dissmissal happends on worker threads if the result future is mutated by the .succeed() or .fail() methods

# 1.9.0
- [Addition] Add a new `isCollapsedState` signal to DualNavigationControllersSplitDelegate that has a `nil` value until the collapsed state is known. Old `isCollapsedSignal` is deprecated.
- [Addition] Add a new `init(collapsedState:)` method to DualNavigationControllersSplitDelegate that takes a future to get notified of a known collapsed state. The `init` without parameters is deprecated.
- [Change] Deprecate MasterDetailSelection's init with `isCollapsed` signal in favour of init that can handle a `nil` collapsed state
- [Bug fix] DualNavigationControllersSplitDelegate's `isCollapsedSignal` didn't signal `false` when moving from collapsed state to not collapsed (multitasking/rotation)
- [Bug fix] DualNavigationControllersSplitDelegate's `isCollapsedSignal` didn't signal anything on iOS 13 ([issue #54](https://github.com/iZettle/Presentation/issues/54))

# 1.8.1
- [Bug fix] Revert a change of the default SplitVC delegate `isCollapsed` value that doesn't work as expected because it's used before the vc is added to the screen and the value is not reliable

# 1.8.0
- [Bug fix] Fixed a recursive delegate call issue in modal presentstions.
- [Bug fix] Added a workaround for a navigation bar layout issue in iOS 13.
- [Addition] Added support for Swift Package Manager.

# 1.7.0
- [Big fix] Fix presentation lifecycle management on iOS 13 when swiping down a modal sheet
- [Addition] Expose a custom adaptive presentation delegate with reactive interface

# 1.6.1
- Update Flow dependency and pin it to a compatible version

# 1.6.0
- [Bug fix] Add DEBUG compiler flag in Debug mode to enable the debug-only functionality
- [Addition] Expose raw presentation events in addition to logs

# 1.5.0
Swift 5 update

# 1.4.1
- Add `willShowViewControllerSignal` to `UINavigationController` that reflects UINavigationControllerDelegate's `navigationController(_:willShow:animated:)` delegate method.

# 1.4.0
- Add support for Signals in Presentation onValue
- Fix MaterDetailSelection retain cycle
- Add `materialize` overload for void result type and `materialize(into:)` for disposable result type
- CI aditions: SwiftLint,CircleCi configs, Xcode 10 project updates

# 1.3.0
- Add a static function `prefersNavigationBarHidden(Bool)` to PresentationOptions to return option based on navigation bar  preference passed as a Bool.
- Implement behaviour to support fallbacks on current client implementations
- Implement a use-case in `Examples/StylesAndOptions/Example.xcodeproj` and add UI test to secure the new use-case.

# 1.2.2

- Bugfix: When disposing the bag passed to `present`'s `configure` closure  `present`'s returned future was not completed, hence resulting in the presented view controller being leaked.

# 1.2.1

- Remove Carthage copy phase to avoid iTunes connect invalid Bundle error [#10]
- Update Flow to 1.3

# 1.2.0

- Updated modallyPresentQueued to accept an options parameter instead of animated and improved handling of `.failOnBlock`. Old version has been deprecated.

# 1.1.0

- Renamed `dismiss()` to `installDismiss()`
- Added more configurable `modally` presentation style. E.g. `.modally(presentationStyle: .formSheet)`
- Added support to present a popover from a bar button item as well.
- Fixed issue where presenting a presentable returning a signal would not terminate the returned finite signal if externally dismissed (such as when dismissing from installed dismiss button), 
  resulting in a potential memory leak (view controller not being released).
  - Bumped to require Flow 1.2.

# 1.0

This is the first public release of the Presentation library.
