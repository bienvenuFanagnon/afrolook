/// getCurrencyBalance Completion Listener
library;

/// Invoked when the SDK completes the getCurrencyBalance successfully.
///
/// Native SDK Reference
/// - Android: onGetCurrencyBalanceResponse
/// -     iOS: getCurrencyBalanceWithCompletion
typedef TapjoyOnGetCurrencyBalanceSuccessListener = Function(String? currencyName, int balance);

/// Invoked when the SDK failes the setUserID operation.
///
/// Native SDK Reference
/// - Android: onGetCurrencyBalanceResponseFailure
/// -     iOS: getCurrencyBalanceWithCompletion
typedef TapjoyOnGetCurrencyBalanceFailureListener = Function(String? error);