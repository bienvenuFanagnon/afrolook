import '../models/models.dart';
import '../tapjoy_constants.dart';

/// To parse values to be passed from Flutter to the native side via [MethodChannel]
class OutgoingValueParser {
  // Init API //////////////////////////////////////////////////////////////////////////////////////

  /// Maps [appKey] and [adUnits] to the keys and returns the [Map].
  /// ```
  /// { 'appKey': String, 'adUnits': List<String>? }
  /// ```
  static Map<String, dynamic> connect( {required String sdkKey, Map<String, dynamic>? options}) {
  final processedOptions = options == null
          ? null
          : {
              for (final entry in options.entries)
                entry.key: entry.value is Enum
                    ? (entry.value as Enum).index
                    : entry.value,
            };
    final Map<String, dynamic> args = {
      TapjoyConstKey.sdkKey: sdkKey,
      TapjoyConstKey.options: processedOptions
    };
    return args;
  }

  /// Maps [userId] to the key and returns the [Map].
  /// ```
  /// { 'userId': String }
  /// ```
  static Map<String, dynamic> setUserId(String? userId) {
    return {TapjoyConstKey.userId: userId};
  }

  static setUserID({required String? userId}) {
    return {TapjoyConstKey.userId: userId};
  }

  static spendCurrency({required int amount}) {
    return {TapjoyConstKey.amount: amount};
  }

  static awardCurrency({required int amount}) {
    return {TapjoyConstKey.amount: amount};
  }

  static setUserLevel({required int userLevel}) {
    return {TapjoyConstKey.userLevel: userLevel};
  }

  static setMaxLevel({required int maxUserLevel}) {
    return {TapjoyConstKey.maxUserLevel: maxUserLevel};
  }

  static setUserSegment({required TJSegment userSegment}) {
    return {TapjoyConstKey.userSegment: userSegment.getValue()};
  }

  static setUserTags({required Set<String> tags}) {
    return {TapjoyConstKey.userTags: tags.toList()};
  }

  static addUserTag({required String tag}) {
    return {TapjoyConstKey.userTag: tag};
  }

  static removeUserTag({required String tag}) {
    return {TapjoyConstKey.userTag: tag};
  }

  static setEntryPoint({required TJPlacement placement, required TJEntryPoint entryPoint}) {
    return {TapjoyConstKey.placementName: placement.placementName, TapjoyConstKey.entryPoint: entryPoint.index};
  }

  static getEntryPoint({required TJPlacement placement}) {
    return {TapjoyConstKey.placementName: placement.placementName};
  }

  static setUserConsent({required TJStatus userConsent}) {
    return {TapjoyConstKey.userConsent: userConsent.index};
  }

  static setSubjectToGDPR({required TJStatus gdprApplicable}) {
    return {TapjoyConstKey.gdprApplicable: gdprApplicable.index};
  }

  static setBelowConsentAge({required TJStatus belowConsentAge}) {
    return {TapjoyConstKey.belowConsentAge: belowConsentAge.index};
  }

  static setUSPrivacy({required String privacyValue}) {
    return {TapjoyConstKey.privacyValue: privacyValue};
  }

  static optOutAdvertisingID({required bool optOut}) {
    return {TapjoyConstKey.optOut: optOut};
  }

  static trackPurchase({required String currencyCode, required double price}) {
    return {TapjoyConstKey.currencyCode: currencyCode, TapjoyConstKey.price: price};
  }

  static getPlacement({required String placementName}) {
    return {TapjoyConstKey.placementName: placementName};
  }

  static requestContent({required TJPlacement placement}) {
    return {TapjoyConstKey.placementName: placement.placementName};
  }

  static requestOWDContent({required String placementName}) {
    return {TapjoyConstKey.placementName: placementName};
  }

  static showContent({required TJPlacement placement}) {
    return {TapjoyConstKey.placementName: placement.placementName};
  }

  static isContentReady({required TJPlacement placement}) {
    return {TapjoyConstKey.placementName: placement.placementName};
  }

  static isContentAvailable({required TJPlacement placement}) {
    return {TapjoyConstKey.placementName: placement.placementName};
  }
}
