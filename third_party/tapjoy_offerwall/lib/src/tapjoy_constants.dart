// Constants
class TapjoyConst {
  static const String pluginType = 'Flutter';
}

/// Argument Keys
class TapjoyConstKey {
  static const String sdkKey = 'sdkKey';
  static const String options = 'options';
  static const String listener = 'listener';
  static const String userId = 'userId';
  static const String amount = 'amount';
  static const String debugEnabled = 'debugEnabled';
  static const String userConsent = 'userConsent';
  static const String gdprApplicable = 'gdprApplicable';
  static const String belowConsentAge = 'belowConsentAge';
  static const String privacyValue = 'privacyValue';
  static const String optOut = 'optOut';
  static const String currencyCode = 'currencyCode';
  static const String price = 'price';
  static const String placementName = 'placementName';
  static const String userLevel = 'userLevel';
  static const String maxUserLevel = 'maxUserLevel';
  static const String userSegment = 'userSegment';
  static const String userTags = 'userTags';
  static const String userTag = 'userTag';
  static const String entryPoint = 'entryPoint';
  static const String currencyBalance = 'currencyBalance';
  static const String currencyId = 'currencyId';
  static const String requiredAmount = 'requiredAmount';
  static const String loggingLevel = 'loggingLevel';
  static const String customParameter = 'customParameter';
}

class TapjoyArgument {
  static const String successCallback = 'successCallback';
  static const String failureCallback = 'failureCallback';
}

class TapjoyCallback {
  static const String onSetCurrencyBalanceSuccess = 'TJPlacementOnSetCurrencyBalanceSuccess';
  static const String onSetCurrencyBalanceFailure = 'TJPlacementOnSetCurrencyBalanceFailure';
  static const String onSetRequiredAmountSuccess = 'TJPlacementOnSetRequiredAmountSuccess';
  static const String onSetRequiredAmountFailure = 'TJPlacementOnSetRequiredAmountFailure';
}