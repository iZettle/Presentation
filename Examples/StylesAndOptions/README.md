## StylesAndOptions Example

This app allows us to see the way different combinations between presentation styles and options work.
Its main focus is going through the common cases and testing that the UI is as expected.
This gives us more confidence for shipping changes and makes writing tests for new combinations faster.

The app doesn't provide any interesting functionality and is not designed to be pretty :)
On the other hand its implementation can be a useful reference for seeing how to combine results from multiple presentations and what happens if they are disposables and get disposed (check the [AppFlow](Example/AppFlow.swift)).

Note:
We have enabled the debug option to display alerts on memory leaks so if a leak has been introduced it might cause test failures (since the alert will automatically be presented and block the UI interactions).
