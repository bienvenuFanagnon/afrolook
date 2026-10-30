import 'models.dart';
import '../parsers/outgoing_value_parser.dart';
import '../tapjoy_channel_manager.dart';


class TJPrivacyPolicy {

  static const channelName = 'tapjoy_offerwall';

  static TJStatus? intToTJStatus(int? tjStatusValue){
    return tjStatusValue == null? null: TJStatus.values[tjStatusValue];
  }

  /// This is used for setting User’s consent string [userConsentString] to behavioral advertising.
  ///
  /// Native SDK Reference
  /// - Android: isConnected
  /// -     iOS: isConnected
  Future<void> setUserConsent(TJStatus userConsent) async {
    final args = OutgoingValueParser.setUserConsent(userConsent: userConsent);
    return await TapjoyChannelManager.getChannel(channelName).invokeMethod('setUserConsent', args);
  }

  /// This is used for getting User’s consent to behavioral advertising.
  ///
  /// Native SDK Reference
  /// - Android: isConnected
  /// -     iOS: isConnected
  Future<TJStatus?> getUserConsent() async {
    final response = await TapjoyChannelManager.getChannel(channelName).invokeMethod<int>('getUserConsent');
    return intToTJStatus(response);
  }

  /// This can be used by the integrating App to indicate if the user falls in any of the GDPR applicable countries.
  ///
  /// Native SDK Reference
  /// - Android: isConnected
  /// -     iOS: isConnected
  Future<void> setSubjectToGDPR(TJStatus gdprApplicable) async {
    final args = OutgoingValueParser.setSubjectToGDPR(gdprApplicable: gdprApplicable);
    return await TapjoyChannelManager.getChannel(channelName).invokeMethod('setSubjectToGDPR', args);
  }

  /// Returns configured GDPR value.
  ///
  /// Native SDK Reference
  /// - Android: isConnected
  /// -     iOS: isConnected
  Future<TJStatus?> getSubjectToGDPR() async {
    final response = await TapjoyChannelManager.getChannel(channelName).invokeMethod<int>('getSubjectToGDPR');
    return intToTJStatus(response);
  }

  /// Set the consent age (COPPA) flag [belowConsentAge] applied to the user.
  ///
  /// Native SDK Reference
  /// - Android: isConnected
  /// -     iOS: isConnected
  Future<void> setBelowConsentAge(TJStatus belowConsentAge) async {
    final args = OutgoingValueParser.setBelowConsentAge(belowConsentAge: belowConsentAge);
    return await TapjoyChannelManager.getChannel(channelName).invokeMethod('setBelowConsentAge', args);
  }

  /// Returns the consent age (COPPA) flag applied to the user.
  ///
  /// Native SDK Reference
  /// - Android: isConnected
  /// -     iOS: isConnected
  Future<TJStatus?> getBelowConsentAge() async {
    final response = await TapjoyChannelManager.getChannel(channelName).invokeMethod<int>('getBelowConsentAge');
    return intToTJStatus(response);
  }

  /// Set US Privacy value [privacyValue] to behavioral advertising such as in the context of CCPA.
  ///
  /// Native SDK Reference
  /// - Android: isConnected
  /// -     iOS: isConnected
  Future<void> setUSPrivacy(String privacyValue) async {
    final args = OutgoingValueParser.setUSPrivacy(privacyValue: privacyValue);
    return await TapjoyChannelManager.getChannel(channelName).invokeMethod('setUSPrivacy', args);
  }

  /// Returns US Privacy value to behavioral advertising such as in the context of CCPA.
  ///
  /// Native SDK Reference
  /// - Android: isConnected
  /// -     iOS: isConnected
  Future<String?> getUSPrivacy() async {
    return await TapjoyChannelManager.getChannel(channelName).invokeMethod('getUSPrivacy');
  }
}