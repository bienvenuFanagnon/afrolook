import 'package:flutter/services.dart';
import 'package:tapjoy_offerwall/src/tapjoy_constants.dart';
import './models/models.dart';

class TapjoyMethodCallHandler {

  // Triggers corresponding listener functions.
  static Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {

      // Tapjoy connect Events
      case 'TapjoyOnConnectSuccess':
        return _onConnectSuccessListener!();

      case 'TapjoyOnConnectFailure':
        return _onConnectFailureListener!(call.arguments["code"], call.arguments["message"]);

      case 'TapjoyOnConnectWarning':
        return _onConnectWarningListener!(call.arguments["code"], call.arguments["message"]);

      // Tapjoy setUserID Events
      case 'TapjoyOnSetUserIDSuccess':
        return _onSetUserIDSuccessListener!();

      case 'TapjoyOnSetUserIDFailure':
        return _onSetUserIDFailureListener!(call.arguments);

      // Tapjoy getCurrencyBalance Events
      case 'TapjoyOnGetCurrencyBalanceSuccess':
        return _onGetCurrencyBalanceSuccessListener!(call.arguments["currencyName"], call.arguments["balance"]);

      case 'TapjoyOnGetCurrencyBalanceFailure':
        return _onGetCurrencyBalanceFailureListener!(call.arguments);

      // Tapjoy spendCurrency Events
      case 'TapjoyOnSpendCurrencySuccess':
        return _onSpendCurrencySuccessListener!(call.arguments["currencyName"], call.arguments["balance"]);

      case 'TapjoyOnSpendCurrencyFailure':
        return _onSpendCurrencyFailureListener!(call.arguments);

      // Tapjoy awardCurrency Events
      case 'TapjoyOnAwardCurrencySuccess':
        return _onAwardCurrencySuccessListener!(call.arguments["currencyName"], call.arguments["balance"]);

      case 'TapjoyOnAwardCurrencyFailure':
        return _onAwardCurrencyFailureListener!(call.arguments);

      // TJPlacement events
      case 'onRequestSuccess':
        return onRequestSuccess(call.arguments);

      case 'onRequestFailure':
        return onRequestFailure(call.arguments);

      case 'onContentReady':
        return onContentReady(call.arguments);

      case 'onContentShow':
        return onContentShow(call.arguments);

      case 'onContentDismiss':
        return onContentDismiss(call.arguments);

      case TapjoyCallback.onSetCurrencyBalanceSuccess:
        return setCurrencyBalanceSuccess(call.arguments);

      case TapjoyCallback.onSetCurrencyBalanceFailure:
        return setCurrencyBalanceFailure(call.arguments);

      case TapjoyCallback.onSetRequiredAmountSuccess:
        return setRequiredAmountSuccess(call.arguments);

      case TapjoyCallback.onSetRequiredAmountFailure:
        return setRequiredAmountFailure(call.arguments);

      default:
        throw UnimplementedError("Method not implemented: ${call.method}");
   }
  }


  // TapjoyOnConnectSuccessListener listener
  static TapjoyOnConnectSuccessListener? _onConnectSuccessListener;
  static void setOnConnectSuccessListener(TapjoyOnConnectSuccessListener? listener) {
    _onConnectSuccessListener = listener;
  }

  // TapjoyOnConnectFailureListener listener
  static TapjoyOnConnectFailureListener? _onConnectFailureListener;
  static void setOnConnectFailureListener(TapjoyOnConnectFailureListener? listener) {
    _onConnectFailureListener = listener;
  }

  // TapjoyOnConnectWarningListener listener
  static TapjoyOnConnectWarningListener? _onConnectWarningListener;
  static void setOnConnectWarningListener(TapjoyOnConnectWarningListener? listener) {
    _onConnectWarningListener = listener;
  }

  // TapjoyOnSetUserIDSuccessListener listener
  static TapjoyOnSetUserIDSuccessListener? _onSetUserIDSuccessListener;
  static void setOnSetUserIDSuccess(TapjoyOnSetUserIDSuccessListener? listener) {
    _onSetUserIDSuccessListener = listener;
  }

  // TapjoyOnSetUserIDFailureListener listener
  static TapjoyOnSetUserIDFailureListener? _onSetUserIDFailureListener;
  static void setOnSetUserIDFailure(TapjoyOnSetUserIDFailureListener? listener) {
    _onSetUserIDFailureListener = listener;
  }

  // TapjoyOnGetCurrencyBalanceSuccessListener listener
  static TapjoyOnGetCurrencyBalanceSuccessListener? _onGetCurrencyBalanceSuccessListener;
  static void setOnGetCurrencyBalanceSuccess(TapjoyOnGetCurrencyBalanceSuccessListener? listener) {
    _onGetCurrencyBalanceSuccessListener = listener;
  }

  // TapjoyOnGetCurrencyBalanceFailureListener listener
  static TapjoyOnGetCurrencyBalanceFailureListener? _onGetCurrencyBalanceFailureListener;
  static void setOnGetCurrencyBalanceFailure(TapjoyOnGetCurrencyBalanceFailureListener? listener) {
    _onGetCurrencyBalanceFailureListener = listener;
  }

  // TapjoyOnSpendCurrencySuccessListener listener
  static TapjoyOnSpendCurrencySuccessListener? _onSpendCurrencySuccessListener;
  static void setOnSpendCurrencySuccess(TapjoyOnSpendCurrencySuccessListener? listener) {
    _onSpendCurrencySuccessListener = listener;
  }

  // TapjoyOnSpendCurrencyFailureListener listener
  static TapjoyOnSpendCurrencyFailureListener? _onSpendCurrencyFailureListener;
  static void setOnSpendCurrencyFailure(TapjoyOnSpendCurrencyFailureListener? listener) {
    _onSpendCurrencyFailureListener = listener;
  }

  // TapjoyOnAwardCurrencySuccessListener listener
  static TapjoyOnAwardCurrencySuccessListener? _onAwardCurrencySuccessListener;
  static void setOnAwardCurrencySuccess(TapjoyOnAwardCurrencySuccessListener? listener) {
    _onAwardCurrencySuccessListener = listener;
  }

  // TapjoyOnAwardCurrencyFailureListener listener
  static TapjoyOnAwardCurrencyFailureListener? _onAwardCurrencyFailureListener;
  static void setOnAwardCurrencyFailure(TapjoyOnAwardCurrencyFailureListener? listener) {
    _onAwardCurrencyFailureListener = listener;
  }

  // TJPlacement onRequestSuccess
  static void onRequestSuccess(arguments) {
    var placement = TJPlacement.findPlacement(arguments);
    placement?.onRequestSuccess?.call(placement);
  }

  // TJPlacement onRequestFailure
  static void onRequestFailure(arguments) {
    var error =  arguments["error"];
    var placementName = arguments["placementName"];
    var placement = TJPlacement.findPlacement(placementName);
    placement?.onRequestFailure?.call(placement, error);
  }

  // TJPlacement onContentReady
  static void onContentReady(arguments) {
    var placement = TJPlacement.findPlacement(arguments);
    placement?.onContentReady?.call(placement);
  }

  // TJPlacement onContentShow
  static void onContentShow(arguments) {
    var placement = TJPlacement.findPlacement(arguments);
    placement?.onContentShow?.call(placement);
  }
  // TJPlacement onContentDismiss
  static void onContentDismiss(arguments) {
    var placement = TJPlacement.findPlacement(arguments);
    placement?.onContentDismiss?.call(placement);
  }

  // TJPlacement setCurrencyBalance success
  static void setCurrencyBalanceSuccess(arguments) {
    var placement = TJPlacement.findPlacement(arguments);
    placement?.onSetCurrencyBalanceSuccess?.call(placement);
  }

  // TJPlacement setCurrencyBalance failure
  static void setCurrencyBalanceFailure(arguments) {
    var placementName = arguments["placementName"];
    var placement = TJPlacement.findPlacement(placementName);
    var error =  arguments["error"];
    placement?.onSetCurrencyBalanceFailure?.call(placement, error);
  }

  // TJPlacement setRequiredAmount success
  static void setRequiredAmountSuccess(arguments) {
    var placement = TJPlacement.findPlacement(arguments);
    placement?.onSetRequiredAmountSuccess?.call(placement);
  }

  // TJPlacement setRequiredAmount failure
  static void setRequiredAmountFailure(arguments) {
    var placementName = arguments["placementName"];
    var placement = TJPlacement.findPlacement(placementName);
    var error =  arguments["error"];
    placement?.onSetRequiredAmountFailure?.call(placement, error);
  }
}
