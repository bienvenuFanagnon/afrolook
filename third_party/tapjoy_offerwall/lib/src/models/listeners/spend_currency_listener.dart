/// spendCurrency Completion Listener
library;

/// Invoked when the SDK completes the spendCurrency successfully.
///
/// Native SDK Reference
/// - Android: onSpendCurrencyResponse
/// -     iOS: spendCurrency
typedef TapjoyOnSpendCurrencySuccessListener = Function(String? currencyName, int balance);

/// Invoked when the SDK failes the setUserID operation.
///
/// Native SDK Reference
/// - Android: onSpendCurrencyResponseFailure
/// -     iOS: spendCurrency
typedef TapjoyOnSpendCurrencyFailureListener = Function(String? error);