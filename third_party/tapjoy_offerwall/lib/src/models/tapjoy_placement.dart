import 'models.dart';
import '../parsers/outgoing_value_parser.dart';
import '../tapjoy_channel_manager.dart';
import '../tapjoy_constants.dart';

class TJPlacement {

  /// TJplacement repository
  static final _placementMap = <String, TJPlacement>{};
  static const channelName = 'tapjoy_offerwall';

  final String placementName;

  TJPlacementOnRequestSuccessListener? onRequestSuccess;
  TJPlacementOnRequestFailureListener? onRequestFailure;
  TJPlacementOnContentReadyListener? onContentReady;
  TJPlacementOnContentShowListener? onContentShow;
  TJPlacementOnContentDismissListener? onContentDismiss;
  TJPlacementOnSetCurrencyBalanceSuccessListener? onSetCurrencyBalanceSuccess;
  TJPlacementOnSetCurrencyBalanceFailureListener? onSetCurrencyBalanceFailure;
  TJPlacementOnSetRequiredAmountSuccessListener? onSetRequiredAmountSuccess;
  TJPlacementOnSetRequiredAmountFailureListener? onSetRequiredAmountFailure;

  TJPlacement._(this.placementName);

  static Future<TJPlacement> getPlacement({required String placementName, 
    TJPlacementOnRequestSuccessListener? onRequestSuccess, 
    TJPlacementOnRequestFailureListener? onRequestFailure, 
    TJPlacementOnContentReadyListener? onContentReady, 
    TJPlacementOnContentShowListener? onContentShow, 
    TJPlacementOnContentDismissListener? onContentDismiss}) async {
      
    if(TJPlacement._placementMap[placementName] == null){
      TJPlacement._placementMap[placementName] = TJPlacement._(placementName);
    }
    TJPlacement placement = TJPlacement._placementMap[placementName]!;
    placement.onRequestSuccess = onRequestSuccess;
    placement.onRequestFailure = onRequestFailure;
    placement.onContentReady = onContentReady;
    placement.onContentShow = onContentShow;
    placement.onContentDismiss = onContentDismiss;

    final args = OutgoingValueParser.getPlacement(placementName: placementName);

    await TapjoyChannelManager.getChannel(channelName).invokeMethod<void>('getPlacement', args);

    return placement;
  }

  static TJPlacement? findPlacement(String placementName){
    return _placementMap[placementName];
  }

  /// Sends the placement request to the server
  ///
  /// Native SDK Reference
  /// - Android: requestContent
  /// -     iOS: requestContent
  Future<void> requestContent() async {
    final args = OutgoingValueParser.requestContent(placement: this);

    return await TapjoyChannelManager.getChannel(channelName).invokeMethod('requestContent', args);
  }

  /// Sends the placement request to the server
  ///
  /// Native SDK Reference
  /// - Android: showContent
  /// -     iOS: showContent
  Future<void> showContent() async {
    final args = OutgoingValueParser.showContent(placement: this);

    return await TapjoyChannelManager.getChannel(channelName).invokeMethod('showContent', args);
  }

  /// Sends the placement request to the server
  ///
  /// Native SDK Reference
  /// - Android: isContentReady
  /// -     iOS: isContentReady
  Future<bool> isContentReady() async {
     final args = OutgoingValueParser.isContentReady(placement: this);

   return await TapjoyChannelManager.getChannel(channelName).invokeMethod('isContentReady', args);
  }

  /// Sends the placement request to the server
  ///
  /// Native SDK Reference
  /// - Android: isContentAvailable
  /// -     iOS: isContentAvailable
  Future<bool> isContentAvailable() async {
    final args = OutgoingValueParser.isContentAvailable(placement: this);

    return await TapjoyChannelManager.getChannel(channelName).invokeMethod('isContentAvailable', args);
  }

  /// Sets the entry point for this placement instance.
  ///
  /// Native SDK Reference
  /// - Android: setEntryPoint
  /// -     iOS: setEntryPoint
  Future<void> setEntryPoint(TJEntryPoint entryPoint){
    final args = OutgoingValueParser.setEntryPoint(placement: this, entryPoint: entryPoint);
    
    return TapjoyChannelManager.getChannel(channelName).invokeMethod<void>('setEntryPoint', args);
  }

  /// Gets the entry point for this placement instance.
  ///
  /// Native SDK Reference
  /// - Android: getEntryPoint
  /// -     iOS: getEntryPoint
  Future<TJEntryPoint?> getEntryPoint() async {
    final args = OutgoingValueParser.getEntryPoint(placement: this);
    final entryPointValue = await TapjoyChannelManager.getChannel(channelName).invokeMethod<int>('getEntryPoint', args);

    return entryPointValue == null? null: TJEntryPoint.values[entryPointValue];
  }

  /// Sets the currency balance. Only the balance of self-managed currencies can be set in this way.
  ///
  /// Native SDK Reference
  /// - Android: setCurrencyBalance
  /// -     iOS: -setBalance:forCurrencyId:withCompletion:
  Future<void> setCurrencyBalance({required int currencyBalance,
                                  required String currencyId,
                                  TJPlacementOnSetCurrencyBalanceSuccessListener? onSuccess,
                                  TJPlacementOnSetCurrencyBalanceFailureListener? onFailure}) async {
    onSetCurrencyBalanceSuccess = onSuccess;
    onSetCurrencyBalanceFailure = onFailure;
    final args = {
      TapjoyConstKey.placementName: placementName,
      TapjoyConstKey.currencyBalance: currencyBalance,
      TapjoyConstKey.currencyId: currencyId,
      TapjoyArgument.successCallback: TapjoyCallback.onSetCurrencyBalanceSuccess,
      TapjoyArgument.failureCallback: TapjoyCallback.onSetCurrencyBalanceFailure
    };

    return await TapjoyChannelManager.getChannel(channelName).invokeMethod<void>('setCurrencyBalance', args);
  }

  /// Sets the required amount for the given currency id.
  ///
  /// Native SDK Reference
  /// - Android: setRequiredAmount
  /// -     iOS: -setRequiredAmount:forCurrencyId:withCompletion:
  Future<void> setRequiredAmount({required int requiredAmount,
                                  required String currencyId,
                                  TJPlacementOnSetRequiredAmountSuccessListener? onSuccess,
                                  TJPlacementOnSetRequiredAmountFailureListener? onFailure}) async {
    onSetRequiredAmountSuccess = onSuccess;
    onSetRequiredAmountFailure = onFailure;
    final args = {
      TapjoyConstKey.placementName: placementName,
      TapjoyConstKey.requiredAmount: requiredAmount,
      TapjoyConstKey.currencyId: currencyId,
      TapjoyArgument.successCallback: TapjoyCallback.onSetRequiredAmountSuccess,
      TapjoyArgument.failureCallback: TapjoyCallback.onSetRequiredAmountFailure
    };

    return await TapjoyChannelManager.getChannel(channelName).invokeMethod<void>('setRequiredAmount', args);
  }
}