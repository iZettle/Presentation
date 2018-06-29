# 1.1

- Renamed `dismiss()` to `installDismiss()`
- Added more configurable `modally` presentation style. E.g. `.modally(presentationStyle: .formSheet)`
- Added support to present a popover from a bar button item as well.
- Fixed issue where presenting a presentable returning a signal would not terminate the returned finite signal if externally dismissed (such as when dismissing from installed dismiss button), 
  resulting in a potential memory leak (view controller not being released).
  - Added a new MessagesUsingForms example showcasing the Messages example updated to use the Form framework.

# 1.0

This is the first public release of the Presentation library.
