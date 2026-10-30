/// setUserID Completion Listener
library;

/// Invoked when the SDK completes the setUserID successfully.
///
/// Native SDK Reference
/// - Android: onSetUserIDSuccess
/// -     iOS: setUserIDWithCompletion
typedef TapjoyOnSetUserIDSuccessListener = Function();

/// Invoked when the SDK failes the setUserID operation.
///
/// Native SDK Reference
/// - Android: onSetUserIDFailure
/// -     iOS: setUserIDWithCompletion
typedef TapjoyOnSetUserIDFailureListener = Function(String? error);

