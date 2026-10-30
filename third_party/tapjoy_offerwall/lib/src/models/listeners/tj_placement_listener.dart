import '../tapjoy_placement.dart';


/// TJPlacement Listener

/// Invoked  when a content request for the given [placement] is successfully send to the server.
/// 
/// Native SDK Reference
/// - Android: onRequestSuccess
/// -     iOS: onRequestSuccess
typedef TJPlacementOnRequestSuccessListener = Function(TJPlacement placement);

/// Invoked  when a content request for the given [placement] is failed to send to and/or processed on the server with [error].
/// 
/// Native SDK Reference
/// - Android: onRequestFailure
/// -     iOS: onRequestFailure
typedef TJPlacementOnRequestFailureListener = Function(TJPlacement placement, String? error);

/// Invoked when a content for the given [placement] is ready to show.
///
/// Native SDK Reference
/// - Android: onContentReady
/// -     iOS: onContentReady
typedef TJPlacementOnContentReadyListener = Function(TJPlacement placement);

/// Invoked when a content for the given [placement] is showing.
///
/// Native SDK Reference
/// - Android: onContentShow
/// -     iOS: onContentShow
typedef TJPlacementOnContentShowListener = Function(TJPlacement placement);

/// Invoked when a content for the given [placement] is dismissed.
///
/// Native SDK Reference
/// - Android: onContentDismiss
/// -     iOS: onContentDismiss
typedef TJPlacementOnContentDismissListener = Function(TJPlacement placement);

/// Invoked when the SDK completes the setCurrencyBalance successfully for a given [placement].
///
/// Native SDK Reference
/// - Android: onSetCurrencyBalanceSuccess
/// -     iOS: -setBalance:forCurrencyId:withCompletion:
typedef TJPlacementOnSetCurrencyBalanceSuccessListener = Function(TJPlacement placement);

/// Invoked when the SDK failes the setCurrencyBalance operation for a given [placement].
///
/// Native SDK Reference
/// - Android: onSetCurrencyBalanceFailure
/// -     iOS: -setBalance:forCurrencyId:withCompletion:
typedef TJPlacementOnSetCurrencyBalanceFailureListener = Function(TJPlacement placement, String? error);


/// Invoked when the SDK completes the setRequiredAmount successfully for a given [placement].
///
/// Native SDK Reference
/// - Android: onSetCurrencyAmountRequiredSuccess
/// -     iOS: -setRequiredAmount:forCurrencyId:withCompletion:
typedef TJPlacementOnSetRequiredAmountSuccessListener = Function(TJPlacement placement);

/// Invoked when the SDK failes the setRequiredAmount operation for a given [placement].
///
/// Native SDK Reference
/// - Android: onSetCurrencyAmountRequiredFailure
/// -     iOS: -setRequiredAmount:forCurrencyId:withCompletion:
typedef TJPlacementOnSetRequiredAmountFailureListener = Function(TJPlacement placement, String? error);