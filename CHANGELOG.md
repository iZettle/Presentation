# 1.3.0

- Updated to Flow 1.3

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
