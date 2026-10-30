import 'package:flutter/services.dart';
import '../parsers/outgoing_value_parser.dart';
import '../tapjoy_channel_manager.dart';

class TJOfferwallDiscover {

  MethodChannel offerwallDiscoverChannel = TapjoyChannelManager.getChannel('tapjoy_offerwall_discover');

  /// Native SDK Reference
  /// - Android: requestOWDContent
  /// -     iOS: requestOWDContent
  Future<void> requestOWDContent(String placementName) async {
    final args = OutgoingValueParser.requestOWDContent(placementName: placementName);
    return await offerwallDiscoverChannel.invokeMethod('requestOWDContent', args);
  }

  Future<void> clearOWDContent() async {
    return await offerwallDiscoverChannel.invokeMethod('clearOWDContent');
  }
}