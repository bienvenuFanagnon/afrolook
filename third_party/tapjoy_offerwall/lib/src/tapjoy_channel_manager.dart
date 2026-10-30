import 'dart:async';
import 'package:flutter/services.dart';
import 'tapjoy_method_call_handler.dart';

class TapjoyChannelManager {

  static const String tapjoyOfferwallChannel = 'tapjoy_offerwall';
  static const String tapjoyOfferwallDiscoverChannel = 'tapjoy_offerwall_discover';

  static final Map<String, MethodChannel> _channels = {
    tapjoyOfferwallChannel : const MethodChannel(tapjoyOfferwallChannel)
  ..setMethodCallHandler(TapjoyMethodCallHandler.handleMethodCall),
    tapjoyOfferwallDiscoverChannel : const MethodChannel(tapjoyOfferwallDiscoverChannel)
  };

  static EventChannel eventChannel = const EventChannel('tapjoy_offerwall_events');
  final StreamController<Map<String, dynamic>> eventStreamController = StreamController<Map<String, dynamic>>.broadcast();

  static MethodChannel getChannel(String name) {
    return _channels[name]!;
  }
  TapjoyChannelManager._internal() {
    eventChannel.receiveBroadcastStream().listen((dynamic data) {
      try {
        _onEvent((data as Map<dynamic, dynamic>).cast<String, dynamic>());
      } catch (e) {
        _onError(e);
      }
    }, onError: _onError);
  }

  static final TapjoyChannelManager instance = TapjoyChannelManager._internal();

  factory TapjoyChannelManager() {
    return instance;
  }

  Stream<Map<String, dynamic>> get events => eventStreamController.stream;

  void _onEvent(Map<String, dynamic> event) {
    eventStreamController.add(event);
  }

  void _onError(dynamic error) {
    eventStreamController.addError(error);
  }
}