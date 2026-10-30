/// Init Completion Listener
library;

/// Invoked when the SDK completes the init process for the first time.
/// - This callback is called only once per session after the first init.
///
/// Native SDK Reference
/// - Android: onConnectSuccess
/// -     iOS: TJC_CONNECT_SUCCESS
typedef TapjoyOnConnectSuccessListener = Function();

/// Invoked when the SDK failes the init process.
///
/// Native SDK Reference
/// - Android: onConnectFailure
/// -     iOS: TJC_CONNECT_FAILED
typedef TapjoyOnConnectFailureListener = Function(int code, String? error);

/// Invoked when there is a warning during connect.
///
/// Native SDK Reference
/// - Android: onConnectWarning
/// -     iOS: TJC_CONNECT_WARNING
typedef TapjoyOnConnectWarningListener = Function(int code, String? warning);