import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ayet_sdk_v2_platform_interface.dart';

/// An implementation of [AyetSdkV2Platform] that uses method channels.
class MethodChannelAyetSdkV2 extends AyetSdkV2Platform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ayet_sdk_v2');

  /// The event channel for receiving native SDK logs.
  @visibleForTesting
  final logChannel = const EventChannel('ayet_sdk_v2/logs');

  StreamSubscription<dynamic>? _logSubscription;

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  // ==================== Initialization ====================

  @override
  Future<void> init({
    required int placementId,
    required String externalIdentifier,
  }) async {
    await methodChannel.invokeMethod('init', {
      'placementId': placementId,
      'externalIdentifier': externalIdentifier,
    });
  }

  @override
  Future<void> setDebug(bool enabled) async {
    await methodChannel.invokeMethod('setDebug', {'enabled': enabled});

    if (enabled) {
      _startLogListener();
    } else {
      _stopLogListener();
    }
  }

  void _startLogListener() {
    _logSubscription ??= logChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final level = event['level'] as String?;
        final tag = event['tag'] as String?;
        final message = event['message'] as String?;
        if (tag != null && message != null) {
          debugPrint(
            '[AyetSDK][$tag] ${level != null && level != 'DEBUG' ? '$level: ' : ''}$message',
          );
        }
      }
    });
  }

  void _stopLogListener() {
    _logSubscription?.cancel();
    _logSubscription = null;
  }

  @override
  Future<void> setFullscreenMode(bool enabled) async {
    await methodChannel.invokeMethod('setFullscreenMode', {'enabled': enabled});
  }

  // ==================== URL Configuration ====================

  @override
  Future<void> setBaseUrl(String url) async {
    await methodChannel.invokeMethod('setBaseUrl', {'url': url});
  }

  @override
  Future<void> setOfferwallBaseUrl(String url) async {
    await methodChannel.invokeMethod('setOfferwallBaseUrl', {'url': url});
  }

  @override
  Future<void> setRewardStatusBaseUrl(String url) async {
    await methodChannel.invokeMethod('setRewardStatusBaseUrl', {'url': url});
  }

  @override
  Future<void> setSurveywallBaseUrl(String url) async {
    await methodChannel.invokeMethod('setSurveywallBaseUrl', {'url': url});
  }

  // ==================== User Properties ====================

  @override
  Future<void> setAge(int age) async {
    await methodChannel.invokeMethod('setAge', {'age': age});
  }

  @override
  Future<void> setGender(AyetGender gender) async {
    final genderString = switch (gender) {
      AyetGender.male => 'MALE',
      AyetGender.female => 'FEMALE',
      AyetGender.nonBinary => 'NON_BINARY',
    };
    await methodChannel.invokeMethod('setGender', {'gender': genderString});
  }

  @override
  Future<void> setTrackingCustom1(String value) async {
    await methodChannel.invokeMethod('setTrackingCustom1', {'value': value});
  }

  @override
  Future<void> setTrackingCustom2(String value) async {
    await methodChannel.invokeMethod('setTrackingCustom2', {'value': value});
  }

  @override
  Future<void> setTrackingCustom3(String value) async {
    await methodChannel.invokeMethod('setTrackingCustom3', {'value': value});
  }

  @override
  Future<void> setTrackingCustom4(String value) async {
    await methodChannel.invokeMethod('setTrackingCustom4', {'value': value});
  }

  @override
  Future<void> setTrackingCustom5(String value) async {
    await methodChannel.invokeMethod('setTrackingCustom5', {'value': value});
  }

  // ==================== Display Methods ====================

  @override
  Future<void> showOfferwall(dynamic adSlot) async {
    if (adSlot is! int && adSlot is! String) {
      throw ArgumentError('adSlot must be an int or String');
    }
    await methodChannel.invokeMethod('showOfferwall', {'adSlot': adSlot});
  }

  @override
  Future<void> showSurveywall(dynamic adSlot) async {
    if (adSlot is! int && adSlot is! String) {
      throw ArgumentError('adSlot must be an int or String');
    }
    await methodChannel.invokeMethod('showSurveywall', {'adSlot': adSlot});
  }

  @override
  Future<void> showRewardStatus() async {
    await methodChannel.invokeMethod('showRewardStatus');
  }

  // ==================== API Methods ====================

  @override
  Future<String?> getOffers(dynamic adSlot) async {
    if (adSlot is! int && adSlot is! String) {
      throw ArgumentError('adSlot must be an int or String');
    }
    return await methodChannel.invokeMethod<String>('getOffers', {
      'adSlot': adSlot,
    });
  }
}
