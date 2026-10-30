import 'dart:async';
import './tapjoy_channel_manager.dart';
import 'tapjoy_method_call_handler.dart';
import 'models/models.dart';
import 'tapjoy_constants.dart';
import 'parsers/incoming_value_parser.dart';
import 'parsers/outgoing_value_parser.dart';

const flutterPluginVersion = '14.6.0';
const flutterPluginVersionSuffix = '';

class Tapjoy {

  static const channelName = 'tapjoy_offerwall';

  /** SDK Init API ===============================================================================*/

  /// Initializes the Tapjoy SDK with [sdkKey] and [options]. [onConnectSuccess] callback will be called on successful connect call. [onConnectFailure] callback will be called otherwise.
  ///
  /// Native SDK Reference
  /// - Android: connect
  /// -     iOS: connect
  static Future<void> connect( {required String sdkKey, Map<String, dynamic>? options, TapjoyOnConnectSuccessListener? onConnectSuccess, TapjoyOnConnectFailureListener? onConnectFailure, TapjoyOnConnectWarningListener? onConnectWarning}) async {
    final args = OutgoingValueParser.connect(sdkKey: sdkKey, options: options);

    TapjoyMethodCallHandler.setOnConnectSuccessListener(onConnectSuccess);
    TapjoyMethodCallHandler.setOnConnectFailureListener(onConnectFailure);
    TapjoyMethodCallHandler.setOnConnectWarningListener(onConnectWarning);
    return TapjoyChannelManager.getChannel(channelName).invokeMethod<void>('connect', args);
  }

  /// Sets the logging level for the Tapjoy SDK.
  ///
  /// Native SDK Reference
  /// - Android: setLoggingLevel
  /// -     iOS: loggingLevel
  static Future<void> setLoggingLevel(TJLoggingLevel loggingLevel) async {
    return TapjoyChannelManager.getChannel(channelName).invokeMethod<void>('setLoggingLevel', {
      TapjoyConstKey.loggingLevel: loggingLevel.index
    });
  }

  /// Gets the current logging level.
  ///
  /// Native SDK Reference
  /// - Android: getLoggingLevel
  /// -     iOS: loggingLevel
  static Future<TJLoggingLevel> getLoggingLevel() async {
    final result = await TapjoyChannelManager.getChannel(channelName).invokeMethod<int>('getLoggingLevel') ?? TJLoggingLevel.error.index;
    return TJLoggingLevel.values[result];
  }

  /// Enable/disable Tapjoy SDK debug mode [debugEnabled].
  ///
  /// Native SDK Reference
  /// - Android: setDebugEnabled
  /// -     iOS: setDebugEnabled
  @Deprecated('Deprecated in 14.4.0. Use setLoggingLevel instead.')
  static Future<void> setDebugEnabled(bool debugEnabled) async {
    return setLoggingLevel(debugEnabled ? TJLoggingLevel.debug : TJLoggingLevel.error);
  }

  /// Helper function to check if SDK is initialized.
  ///
  /// Native SDK Reference
  /// - Android: isConnected
  /// -     iOS: isConnected
  static Future<bool> isConnected() async {

    return await TapjoyChannelManager.getChannel(channelName).invokeMethod('isConnected');
  }

  /// Set/update userID with [userID] [onSetUserIDSuccess] callback will be called on successfull connect call. [onSetUserIDFailure] callback will be called otherwise.
  ///
  /// Native SDK Reference
  /// - Android: setUserID
  /// -     iOS: setUserID
  static Future<void> setUserID( {required String? userId, TapjoyOnSetUserIDSuccessListener? onSetUserIDSuccess, TapjoyOnSetUserIDFailureListener? onSetUserIDFailure}) async {
    final args = OutgoingValueParser.setUserID(userId: userId);

    TapjoyMethodCallHandler.setOnSetUserIDSuccess(onSetUserIDSuccess);
    TapjoyMethodCallHandler.setOnSetUserIDFailure(onSetUserIDFailure);

    return TapjoyChannelManager.getChannel(channelName).invokeMethod<void>('setUserID', args);
  }

  /// Gets the user id
  ///
  /// Native SDK Reference
  /// - Android: getUserID
  /// -     iOS: getUserID
  static Future<String?> getUserID(){
    return TapjoyChannelManager.getChannel(channelName).invokeMethod<String?>('getUserID');
  }

  /// Set custom parameter with [parameter]
  ///
  /// Native SDK Reference
  /// - Android: setCustomParameter
  /// -     iOS: customParameter
  static Future<void>setCustomParameter(String? parameter){
    return TapjoyChannelManager.getChannel(channelName).invokeMethod<void>('setCustomParameter', {  
      TapjoyConstKey.customParameter: parameter
    });
  }

  /// Gets the custom parameter
  ///
  /// Native SDK Reference
  /// - Android: getCustomParameter
  /// -     iOS: customParameter
  static Future<String?> getCustomParameter(){
    return TapjoyChannelManager.getChannel(channelName).invokeMethod<String?>('getCustomParameter');
  }

  /// Gets currency balance, [onGetCurrencyBalanceSuccess] callback will be called on successfull call. [onGetCurrencyBalanceFailure] callback will be called otherwise.
  ///
  /// Native SDK Reference
  /// - Android: getCurrencyBalance
  /// -     iOS: getCurrencyBalanceWithCompletion
  static Future<void> getCurrencyBalance( {TapjoyOnGetCurrencyBalanceSuccessListener? onGetCurrencyBalanceSuccess, TapjoyOnGetCurrencyBalanceFailureListener? onGetCurrencyBalanceFailure}) async {
    TapjoyMethodCallHandler.setOnGetCurrencyBalanceSuccess(onGetCurrencyBalanceSuccess);
    TapjoyMethodCallHandler.setOnGetCurrencyBalanceFailure(onGetCurrencyBalanceFailure);

    return TapjoyChannelManager.getChannel(channelName).invokeMethod<void>('getCurrencyBalance');
  }

  /// Spends currency [amount], [onSpendCurrencySuccess] callback will be called on successfull call. [onSpendCurrencyFailure] callback will be called otherwise.
  ///
  /// Native SDK Reference
  /// - Android: spendCurrency
  /// -     iOS: spendCurrency
  static Future<void> spendCurrency( {required int amount, TapjoyOnSpendCurrencySuccessListener? onSpendCurrencySuccess, TapjoyOnSpendCurrencyFailureListener? onSpendCurrencyFailure}) async {
    final args = OutgoingValueParser.spendCurrency(amount: amount);

    TapjoyMethodCallHandler.setOnSpendCurrencySuccess(onSpendCurrencySuccess);
    TapjoyMethodCallHandler.setOnSpendCurrencyFailure(onSpendCurrencyFailure);

    return TapjoyChannelManager.getChannel(channelName).invokeMethod<void>('spendCurrency', args);
  }

  /// Awards currency [amount], [onAwardCurrencySuccess] callback will be called on successfull call. [onAwardCurrencyFailure] callback will be called otherwise.
  ///
  /// Native SDK Reference
  /// - Android: awardCurrency
  /// -     iOS: awardCurrency
  static Future<void> awardCurrency( {required int amount, TapjoyOnAwardCurrencySuccessListener? onAwardCurrencySuccess, TapjoyOnAwardCurrencyFailureListener? onAwardCurrencyFailure}) async {
    final args = OutgoingValueParser.awardCurrency(amount: amount);

    TapjoyMethodCallHandler.setOnAwardCurrencySuccess(onAwardCurrencySuccess);
    TapjoyMethodCallHandler.setOnAwardCurrencyFailure(onAwardCurrencyFailure);

    return TapjoyChannelManager.getChannel(channelName).invokeMethod<void>('awardCurrency', args);
  }

  /// Set the level of the user.
  ///
  /// Native SDK Reference
  /// - Android: setUserLevel
  /// -     iOS: setUserLevel
  static Future<void> setUserLevel(int userLevel){
    final args = OutgoingValueParser.setUserLevel(userLevel: userLevel);

    return TapjoyChannelManager.getChannel(channelName).invokeMethod<void>('setUserLevel', args);
  }

  /// Gets the level of the user.
  ///
  /// Native SDK Reference
  /// - Android: getUserLevel
  /// -     iOS: getUserLevel
  static Future<int?> getUserLevel(){
    return TapjoyChannelManager.getChannel(channelName).invokeMethod<int>('getUserLevel');
  }

  /// Set the maximum level of the user.
  ///
  /// Native SDK Reference
  /// - Android: setMaxLevel
  /// -     iOS: setMaxLevel
  static Future<void> setMaxLevel(int maxUserLevel){
    final args = OutgoingValueParser.setMaxLevel(maxUserLevel: maxUserLevel);

    return TapjoyChannelManager.getChannel(channelName).invokeMethod<void>('setMaxLevel', args);
  }

  /// Gets the maximum level of the user.
  ///
  /// Native SDK Reference
  /// - Android: getMaxLevel
  /// -     iOS: getMaxLevel
  static Future<int?> getMaxLevel(){
    return TapjoyChannelManager.getChannel(channelName).invokeMethod<int>('getMaxLevel');
  }

  /// Set the segment of the user.
  ///
  /// Native SDK Reference
  /// - Android: setUserSegment
  /// -     iOS: setUserSegment
  static Future<void> setUserSegment(TJSegment userSegment){
    final args = OutgoingValueParser.setUserSegment(userSegment: userSegment);

    return TapjoyChannelManager.getChannel(channelName).invokeMethod<void>('setUserSegment', args);
  }

  /// Gets the segment of the user.
  ///
  /// Native SDK Reference
  /// - Android: getUserSegment
  /// -     iOS: getUserSegment
  static Future<TJSegment?> getUserSegment() async {
    final segment = await TapjoyChannelManager.getChannel(channelName).invokeMethod<int>('getUserSegment');
    return segment == null? null: TJSegment.valueOf(segment);
  }

  /// Sets tags for the user.
  ///
  /// Native SDK Reference
  /// - Android: setUserID
  /// -     iOS: setUserID
  static Future<void> setUserTags(Set<String> tags){
    final args = OutgoingValueParser.setUserTags(tags: tags);

    return TapjoyChannelManager.getChannel(channelName).invokeMethod<void>('setUserTags', args);
  }

  /// Gets the segment of the user.
  ///
  /// Native SDK Reference
  /// - Android: getUserTags
  /// -     iOS: getUserTags
  static Future<Set<String>> getUserTags() async {
    final result = await TapjoyChannelManager.getChannel(channelName).invokeMethod<List<dynamic>?>('getUserTags');

    return IncomingValueParser.getUserSegment(result);
  }

  /// Removes all tags from the user.
  ///
  /// Native SDK Reference
  /// - Android: clearUserTags
  /// -     iOS: clearUserTags
  static Future<void> clearUserTags(){
    return TapjoyChannelManager.getChannel(channelName).invokeMethod<void>('clearUserTags');
  }

  /// Adds the given tag to the user if it is not already present.
  ///
  /// Native SDK Reference
  /// - Android: addUserTag
  /// -     iOS: addUserTag
  static Future<void> addUserTag(String tag){
    final args = OutgoingValueParser.addUserTag(tag: tag);

    return TapjoyChannelManager.getChannel(channelName).invokeMethod<void>('addUserTag', args);
  }

  /// Removes the given tag from the user if it is present.
  ///
  /// Native SDK Reference
  /// - Android: removeUserTag
  /// -     iOS: removeUserTag
  static Future<void> removeUserTag(String tag){
    final args = OutgoingValueParser.removeUserTag(tag: tag);

    return TapjoyChannelManager.getChannel(channelName).invokeMethod<void>('removeUserTag', args);
  }

  /// This is to opt out passing advertising_id param in the subsequent network requests
  ///
  /// Native SDK Reference
  /// - Android: optOutAdvertisingID
  static Future<void> optOutAdvertisingID(bool optOut){
    final args = OutgoingValueParser.optOutAdvertisingID(optOut: optOut);
    return TapjoyChannelManager.getChannel(channelName).invokeMethod<void>('optOutAdvertisingID', args);
  }

  /// Returns the currently set opt out advertising id value
  ///
  /// Native SDK Reference
  /// - Android: getOptOutAdvertisingID
  static Future<bool?> getOptOutAdvertisingID(){
    return TapjoyChannelManager.getChannel(channelName).invokeMethod<bool>('getOptOutAdvertisingID');
  }

  /// Tracks a purchase
  ///
  /// Native SDK Reference
  /// - Android: trackPurchase
  /// - iOS: trackPurchase
  static Future<void> trackPurchase(String currencyCode, double price){
    final args = OutgoingValueParser.trackPurchase(currencyCode: currencyCode, price: price);
    return TapjoyChannelManager.getChannel(channelName).invokeMethod<void>('trackPurchase', args);
  }

  /// Returns the TJPrivacyPolicy instance for calling methods to set GDPR, User's consent, below consent age ,and US Privacy policy flags.
  ///
  /// Native SDK Reference
  /// - Android: getPrivacyPolicy
  /// -     iOS: getPrivacyPolicy
  static TJPrivacyPolicy getPrivacyPolicy() {
    return TJPrivacyPolicy();
  }

  /// Returns the TJPrivacyPolicy instance for calling methods to set GDPR, User's consent, below consent age ,and US Privacy policy flags.
  ///
  /// Native SDK Reference
  /// - Android: getPrivacyPolicy
  /// -     iOS: getPrivacyPolicy
  static Future<TJPlacement?> getPlacement({required String placementName,
    TJPlacementOnRequestSuccessListener? onRequestSuccess,
    TJPlacementOnRequestFailureListener? onRequestFailure,
    TJPlacementOnContentReadyListener? onContentReady,
    TJPlacementOnContentShowListener? onContentShow,
    TJPlacementOnContentDismissListener? onContentDismiss}) async {
    if(await Tapjoy.isConnected() != true){
      return null;
    }

    return TJPlacement.getPlacement(placementName: placementName, onRequestSuccess: onRequestSuccess, onRequestFailure: onRequestFailure, onContentReady: onContentReady, onContentShow: onContentShow, onContentDismiss: onContentDismiss);
  }

  /// Returns the Listeners for OfferwallDiscover.
  static StreamSubscription<Map<String, dynamic>> listen({
    required EventListener onEvent,
    required Function(Object error) onError,
  }) {
    return TapjoyChannelManager().events.listen(onEvent, onError: onError);
  }

  // Returns the version of the plugin - eg: 1.0.0-alpha-rc1
  static String getPluginVersion() {
    if (flutterPluginVersionSuffix.isNotEmpty) {
      return '$flutterPluginVersion-$flutterPluginVersionSuffix';
    } else {
      return flutterPluginVersion;
    }
  }
}


