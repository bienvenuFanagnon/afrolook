import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ayet_sdk_v2_method_channel.dart';

/// Gender enum for user targeting
enum AyetGender { male, female, nonBinary }

abstract class AyetSdkV2Platform extends PlatformInterface {
  /// Constructs a AyetSdkV2Platform.
  AyetSdkV2Platform() : super(token: _token);

  static final Object _token = Object();

  static AyetSdkV2Platform _instance = MethodChannelAyetSdkV2();

  /// The default instance of [AyetSdkV2Platform] to use.
  ///
  /// Defaults to [MethodChannelAyetSdkV2].
  static AyetSdkV2Platform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AyetSdkV2Platform] when
  /// they register themselves.
  static set instance(AyetSdkV2Platform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  // ==================== Initialization ====================

  /// Initialize the SDK with placement ID and external identifier.
  /// This must be called before any other SDK methods.
  Future<void> init({
    required int placementId,
    required String externalIdentifier,
  }) {
    throw UnimplementedError('init() has not been implemented.');
  }

  /// Enable or disable debug logging.
  Future<void> setDebug(bool enabled) {
    throw UnimplementedError('setDebug() has not been implemented.');
  }

  /// Enable or disable fullscreen mode for webviews.
  Future<void> setFullscreenMode(bool enabled) {
    throw UnimplementedError('setFullscreenMode() has not been implemented.');
  }

  // ==================== URL Configuration ====================

  /// Override the default base URL for API calls.
  Future<void> setBaseUrl(String url) {
    throw UnimplementedError('setBaseUrl() has not been implemented.');
  }

  /// Override the offerwall base URL.
  Future<void> setOfferwallBaseUrl(String url) {
    throw UnimplementedError('setOfferwallBaseUrl() has not been implemented.');
  }

  /// Override the reward status base URL.
  Future<void> setRewardStatusBaseUrl(String url) {
    throw UnimplementedError(
      'setRewardStatusBaseUrl() has not been implemented.',
    );
  }

  /// Override the surveywall base URL.
  Future<void> setSurveywallBaseUrl(String url) {
    throw UnimplementedError(
      'setSurveywallBaseUrl() has not been implemented.',
    );
  }

  // ==================== User Properties ====================

  /// Set the user's age for targeting.
  Future<void> setAge(int age) {
    throw UnimplementedError('setAge() has not been implemented.');
  }

  /// Set the user's gender for targeting.
  Future<void> setGender(AyetGender gender) {
    throw UnimplementedError('setGender() has not been implemented.');
  }

  /// Set custom tracking value 1.
  Future<void> setTrackingCustom1(String value) {
    throw UnimplementedError('setTrackingCustom1() has not been implemented.');
  }

  /// Set custom tracking value 2.
  Future<void> setTrackingCustom2(String value) {
    throw UnimplementedError('setTrackingCustom2() has not been implemented.');
  }

  /// Set custom tracking value 3.
  Future<void> setTrackingCustom3(String value) {
    throw UnimplementedError('setTrackingCustom3() has not been implemented.');
  }

  /// Set custom tracking value 4.
  Future<void> setTrackingCustom4(String value) {
    throw UnimplementedError('setTrackingCustom4() has not been implemented.');
  }

  /// Set custom tracking value 5.
  Future<void> setTrackingCustom5(String value) {
    throw UnimplementedError('setTrackingCustom5() has not been implemented.');
  }

  // ==================== Display Methods ====================

  /// Show the offerwall with the given ad slot.
  /// [adSlot] can be either an int (ad slot ID) or a String (ad slot name).
  Future<void> showOfferwall(dynamic adSlot) {
    throw UnimplementedError('showOfferwall() has not been implemented.');
  }

  /// Show the surveywall with the given ad slot.
  /// [adSlot] can be either an int (ad slot ID) or a String (ad slot name).
  Future<void> showSurveywall(dynamic adSlot) {
    throw UnimplementedError('showSurveywall() has not been implemented.');
  }

  /// Show the reward status page.
  Future<void> showRewardStatus() {
    throw UnimplementedError('showRewardStatus() has not been implemented.');
  }

  // ==================== API Methods ====================

  /// Get offers for the given ad slot.
  /// [adSlot] can be either an int (ad slot ID) or a String (ad slot name).
  /// Returns the JSON response as a string, or null if the request failed.
  Future<String?> getOffers(dynamic adSlot) {
    throw UnimplementedError('getOffers() has not been implemented.');
  }
}
