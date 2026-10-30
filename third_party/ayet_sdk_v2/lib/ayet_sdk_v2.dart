import 'ayet_sdk_v2_platform_interface.dart';

export 'ayet_sdk_v2_platform_interface.dart' show AyetGender;

class AyetSdkV2 {
  Future<String?> getPlatformVersion() {
    return AyetSdkV2Platform.instance.getPlatformVersion();
  }

  // ==================== Initialization ====================

  /// Initialize the SDK with placement ID and external identifier.
  /// This must be called before any other SDK methods.
  Future<void> init({
    required int placementId,
    required String externalIdentifier,
  }) {
    return AyetSdkV2Platform.instance.init(
      placementId: placementId,
      externalIdentifier: externalIdentifier,
    );
  }

  /// Enable or disable debug logging.
  Future<void> setDebug(bool enabled) {
    return AyetSdkV2Platform.instance.setDebug(enabled);
  }

  /// Enable or disable fullscreen mode for webviews.
  Future<void> setFullscreenMode(bool enabled) {
    return AyetSdkV2Platform.instance.setFullscreenMode(enabled);
  }

  // ==================== URL Configuration ====================

  /// Override the default base URL for API calls.
  Future<void> setBaseUrl(String url) {
    return AyetSdkV2Platform.instance.setBaseUrl(url);
  }

  /// Override the offerwall base URL.
  Future<void> setOfferwallBaseUrl(String url) {
    return AyetSdkV2Platform.instance.setOfferwallBaseUrl(url);
  }

  /// Override the reward status base URL.
  Future<void> setRewardStatusBaseUrl(String url) {
    return AyetSdkV2Platform.instance.setRewardStatusBaseUrl(url);
  }

  /// Override the surveywall base URL.
  Future<void> setSurveywallBaseUrl(String url) {
    return AyetSdkV2Platform.instance.setSurveywallBaseUrl(url);
  }

  // ==================== User Properties ====================

  /// Set the user's age for targeting.
  Future<void> setAge(int age) {
    return AyetSdkV2Platform.instance.setAge(age);
  }

  /// Set the user's gender for targeting.
  Future<void> setGender(AyetGender gender) {
    return AyetSdkV2Platform.instance.setGender(gender);
  }

  /// Set custom tracking value 1.
  Future<void> setTrackingCustom1(String value) {
    return AyetSdkV2Platform.instance.setTrackingCustom1(value);
  }

  /// Set custom tracking value 2.
  Future<void> setTrackingCustom2(String value) {
    return AyetSdkV2Platform.instance.setTrackingCustom2(value);
  }

  /// Set custom tracking value 3.
  Future<void> setTrackingCustom3(String value) {
    return AyetSdkV2Platform.instance.setTrackingCustom3(value);
  }

  /// Set custom tracking value 4.
  Future<void> setTrackingCustom4(String value) {
    return AyetSdkV2Platform.instance.setTrackingCustom4(value);
  }

  /// Set custom tracking value 5.
  Future<void> setTrackingCustom5(String value) {
    return AyetSdkV2Platform.instance.setTrackingCustom5(value);
  }

  // ==================== Display Methods ====================

  /// Show the offerwall with the given ad slot.
  /// [adSlot] can be either an int (ad slot ID) or a String (ad slot name).
  Future<void> showOfferwall(dynamic adSlot) {
    return AyetSdkV2Platform.instance.showOfferwall(adSlot);
  }

  /// Show the surveywall with the given ad slot.
  /// [adSlot] can be either an int (ad slot ID) or a String (ad slot name).
  Future<void> showSurveywall(dynamic adSlot) {
    return AyetSdkV2Platform.instance.showSurveywall(adSlot);
  }

  /// Show the reward status page.
  Future<void> showRewardStatus() {
    return AyetSdkV2Platform.instance.showRewardStatus();
  }

  // ==================== API Methods ====================

  /// Get offers for the given ad slot.
  /// [adSlot] can be either an int (ad slot ID) or a String (ad slot name).
  /// Returns the JSON response as a string, or null if the request failed.
  Future<String?> getOffers(dynamic adSlot) {
    return AyetSdkV2Platform.instance.getOffers(adSlot);
  }
}
