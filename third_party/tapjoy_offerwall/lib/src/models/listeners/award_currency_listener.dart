/// awardCurrency Completion Listener
library;

/// Invoked when the SDK completes the awardCurrency successfully.
///
/// Native SDK Reference
/// - Android: onAwardCurrencyResponse
/// -     iOS: awardCurrency
typedef TapjoyOnAwardCurrencySuccessListener = Function(String? currencyName, int balance);

/// Invoked when the SDK failes the setUserID operation.
///
/// Native SDK Reference
/// - Android: onAwardCurrencyResponseFailure
/// -     iOS: awardCurrency
typedef TapjoyOnAwardCurrencyFailureListener = Function(String? error);