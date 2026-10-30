package com.tapjoy.flutter

import android.util.Log
import androidx.annotation.NonNull
import androidx.lifecycle.LifecycleObserver
import com.tapjoy.TJActionRequest
import com.tapjoy.TJConnectListener
import com.tapjoy.TJEntryPoint
import com.tapjoy.TJError
import com.tapjoy.TJPlacement
import com.tapjoy.TJPlacementListener
import com.tapjoy.TJSegment
import com.tapjoy.TJSetUserIDListener
import com.tapjoy.TJGetCurrencyBalanceListener
import com.tapjoy.TJSpendCurrencyListener
import com.tapjoy.TJAwardCurrencyListener
import com.tapjoy.TJSetCurrencyAmountRequiredListener
import com.tapjoy.TJSetCurrencyBalanceListener
import com.tapjoy.TJStatus
import com.tapjoy.TJLogLevel
import com.tapjoy.Tapjoy
import com.tapjoy.TapjoyPluginAPI
import android.app.Activity
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.Hashtable
import java.util.concurrent.ConcurrentHashMap

/** TapjoyOfferwallPlugin */
class TapjoyOfferwallPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, LifecycleObserver,
  TJPlacementListener {
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity

  // Listeners
  private lateinit var mConnectListener: TJConnectListener
  val TAG = TapjoyOfferwallPlugin::class.java.simpleName
  private val placementMap = ConcurrentHashMap<String, TJPlacement>()
  private val channelName = "tapjoy_offerwall"

  companion object {
    var activity: Activity? = null
  }

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    val methodChannel = ChannelManager.registerMethodChannel(flutterPluginBinding, channelName)
    val eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "tapjoy_offerwall_events")
    ChannelManager.setupEventChannel(eventChannel)
    val offerwallDiscover = TapjoyOfferwallDiscover()
    offerwallDiscover.registerChannel(flutterPluginBinding)
    methodChannel.setMethodCallHandler(this)
    setListeners()
    flutterPluginBinding
      .platformViewRegistry
      .registerViewFactory("tapjoy_offerwall_discover", TapjoyOfferwallDiscoverViewFactory())
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "isConnected" -> isConnected(result)
      "connect" -> connect(call, result)
      "setUserID" -> setUserID(call, result)
      "getUserID" -> getUserID(call, result)
      "getCurrencyBalance" -> getCurrencyBalance(call, result)
      "spendCurrency" -> spendCurrency(call, result)
      "awardCurrency" -> awardCurrency(call, result)
      "setUserConsent" -> setUserConsent(call, result)
      "getUserConsent" -> getUserConsent(call, result)
      "setSubjectToGDPR" -> setSubjectToGDPR(call, result)
      "getSubjectToGDPR" -> getSubjectToGDPR(call, result)
      "setBelowConsentAge" -> setBelowConsentAge(call, result)
      "getBelowConsentAge" -> getBelowConsentAge(call, result)
      "setUSPrivacy" -> setUSPrivacy(call, result)
      "getUSPrivacy" -> getUSPrivacy(call, result)
      "setUserLevel" -> setUserLevel(call, result)
      "getUserLevel" -> getUserLevel(call, result)
      "setMaxLevel" -> setMaxLevel(call, result)
      "getMaxLevel" -> getMaxLevel(call, result)
      "setUserSegment" -> setUserSegment(call, result)
      "getUserSegment" -> getUserSegment(call, result)
      "setUserTags" -> setUserTags(call, result)
      "getUserTags" -> getUserTags(call, result)
      "clearUserTags" -> clearUserTags(call, result)
      "addUserTag" -> addUserTag(call, result)
      "removeUserTag" -> removeUserTag(call, result)
      "optOutAdvertisingID" -> optOutAdvertisingID(call, result)
      "getOptOutAdvertisingID" -> getOptOutAdvertisingID(call, result)
      "trackPurchase" -> trackPurchase(call, result)
      "getPlacement" -> getPlacement(call, result)
      "requestContent" -> requestContent(call, result)
      "showContent" -> showContent(call, result)
      "isContentReady" -> isContentReady(call, result)
      "isContentAvailable" -> isContentAvailable(call, result)
      "setEntryPoint" -> setEntryPoint(call, result)
      "getEntryPoint" -> getEntryPoint(call, result)
      "setCurrencyBalance" -> setCurrencyBalance(call, result)
      "setRequiredAmount" -> setRequiredAmount(call, result)
      "setLoggingLevel" -> setLoggingLevel(call, result)
      "getLoggingLevel" -> getLoggingLevel(result)
      "setCustomParameter" -> setCustomParameter(call, result)
      "getCustomParameter" -> getCustomParameter(call, result)
      else -> result.notImplemented()
    }
  }

  /** region Base API ============================================================================*/
  private fun setLoggingLevel(@NonNull call: MethodCall, @NonNull result: Result) {
    val loggingLevel = call.argument("loggingLevel") as Int?
      ?: return result.error("ERROR", "loggingLevel is null", null)
    when (loggingLevel) {
      0 -> Tapjoy.setLoggingLevel(TJLogLevel.ERROR)
      1 -> Tapjoy.setLoggingLevel(TJLogLevel.WARNING)
      2 -> Tapjoy.setLoggingLevel(TJLogLevel.INFO)
      3 -> Tapjoy.setLoggingLevel(TJLogLevel.DEBUG)
    }
    return result.success(null)
  }

  private fun getLoggingLevel(@NonNull result: Result) {
    when (Tapjoy.getLoggingLevel()) {
      TJLogLevel.ERROR -> result.success(0)
      TJLogLevel.WARNING -> result.success(1)
      TJLogLevel.INFO -> result.success(2)
      TJLogLevel.DEBUG -> result.success(3)
    }
  }

  private fun isConnected(@NonNull result: Result) {
    return result.success(Tapjoy.isConnected())
  }

  private fun connect(@NonNull call: MethodCall, @NonNull result: Result) {
    if (activity == null) {
      return result.error("ERROR", "Activity is null", null)
    }
    var sdkKey = call.argument<String>("sdkKey")
    var optionsMap = call.argument<HashMap<String, Any?>?>("options")
    if(optionsMap == null) {
      optionsMap = HashMap<String, Any?>()
    }
    val options = Hashtable<String, Any>()
    for ((key, value) in optionsMap) {
      if (value == null) continue
        options[key] = value
    }
    TapjoyPluginAPI.setPlugin("flutter")
    Tapjoy.connect(activity!!.applicationContext, sdkKey, options, mConnectListener)
    return result.success(null)
  }

  private fun setUserID(@NonNull call: MethodCall, @NonNull result: Result) {
    val userId = call.argument("userId") as String?

    Tapjoy.setUserID(userId, object: TJSetUserIDListener{
      override fun onSetUserIDSuccess() {
        ChannelManager.invokeChannelMethod(channelName, "TapjoyOnSetUserIDSuccess", null)
      }

      override fun onSetUserIDFailure(error: String?) {
        ChannelManager.invokeChannelMethod(channelName, "TapjoyOnSetUserIDFailure", error)
      }
    })

    return result.success(null)
  }

  private fun getUserID(@NonNull call: MethodCall, @NonNull result: Result) {
    return result.success(Tapjoy.getUserID())
  }

  private fun setCustomParameter(@NonNull call: MethodCall, @NonNull result: Result) {
    val customParameter = call.argument("customParameter") as String?
    Tapjoy.setCustomParameter(customParameter)
    return result.success(null)
  }

  private fun getCustomParameter(@NonNull call: MethodCall, @NonNull result: Result) {
    return result.success(Tapjoy.getCustomParameter())
  }

  private fun getCurrencyBalance(@NonNull call: MethodCall, @NonNull result: Result) {    
    Tapjoy.getCurrencyBalance(object: TJGetCurrencyBalanceListener{
      override fun onGetCurrencyBalanceResponse(currencyName: String?, balance: Int) {
        ChannelManager.invokeChannelMethod(channelName, "TapjoyOnGetCurrencyBalanceSuccess", hashMapOf( "currencyName" to currencyName, "balance" to balance ))
      }

      override fun onGetCurrencyBalanceResponseFailure(error: String?) {
        ChannelManager.invokeChannelMethod(channelName, "TapjoyOnGetCurrencyBalanceFailure", error)
      }
    })

    return result.success(null)
  }

  private fun spendCurrency(@NonNull call: MethodCall, @NonNull result: Result) {   
    val amount = call.argument("amount") as Int? ?: return result.error("ERROR", "amount is null", null) 
    Tapjoy.spendCurrency(amount, object: TJSpendCurrencyListener{
      override fun onSpendCurrencyResponse(currencyName: String?, balance: Int) {
        ChannelManager.invokeChannelMethod(channelName, "TapjoyOnSpendCurrencySuccess", hashMapOf( "currencyName" to currencyName, "balance" to balance ))
      }

      override fun onSpendCurrencyResponseFailure(error: String?) {
        ChannelManager.invokeChannelMethod(channelName, "TapjoyOnSpendCurrencyFailure", error)
      }
    })

    return result.success(null)
  }

  private fun awardCurrency(@NonNull call: MethodCall, @NonNull result: Result) {   
    val amount = call.argument("amount") as Int? ?: return result.error("ERROR", "amount is null", null) 
    Tapjoy.awardCurrency(amount, object: TJAwardCurrencyListener{
      override fun onAwardCurrencyResponse(currencyName: String?, balance: Int) {
        ChannelManager.invokeChannelMethod(channelName, "TapjoyOnAwardCurrencySuccess", hashMapOf( "currencyName" to currencyName, "balance" to balance ))
      }

      override fun onAwardCurrencyResponseFailure(error: String?) {
        ChannelManager.invokeChannelMethod(channelName, "TapjoyOnAwardCurrencyFailure", error)
      }
    })

    return result.success(null)
  }

  private fun setUserConsent(@NonNull call: MethodCall, @NonNull result: Result) {
    val userConsent = call.argument("userConsent") as Int?
      ?: return result.error("ERROR", "userConsent is null", null)
    Tapjoy.getPrivacyPolicy().userConsent = this.intToTJStatus(userConsent)
    return result.success(null)
  }

  private fun getUserConsent(@NonNull call: MethodCall, @NonNull result: Result) {
    val userConsentStatus = Tapjoy.getPrivacyPolicy().userConsent
    val tjp = Tapjoy.getPrivacyPolicy()
    return result.success(this.tjStatusToNullableInt(userConsentStatus))
  }

  private fun setSubjectToGDPR(@NonNull call: MethodCall, @NonNull result: Result) {
    val gdprApplicable = call.argument("gdprApplicable") as Int?
      ?: return result.error("ERROR", "subjectToGDPR is null", null)
    Tapjoy.getPrivacyPolicy().subjectToGDPR = this.intToTJStatus(gdprApplicable)
    return result.success(null)
  }

  private fun getSubjectToGDPR(@NonNull call: MethodCall, @NonNull result: Result) {
    val gdprApplicableStatus = Tapjoy.getPrivacyPolicy().subjectToGDPR
    return result.success(this.tjStatusToNullableInt(gdprApplicableStatus))
  }

  private fun setBelowConsentAge(@NonNull call: MethodCall, @NonNull result: Result) {
    val belowConsentAge = call.argument("belowConsentAge") as Int?
      ?: return result.error("ERROR", "belowConsentAge is null", null)
    Tapjoy.getPrivacyPolicy().belowConsentAge = this.intToTJStatus(belowConsentAge)
    return result.success(null)
  }

  private fun getBelowConsentAge(@NonNull call: MethodCall, @NonNull result: Result) {
    val belowConsentAgeStatus = Tapjoy.getPrivacyPolicy().belowConsentAge
    return result.success(this.tjStatusToNullableInt(belowConsentAgeStatus))
  }

  private fun setUSPrivacy(@NonNull call: MethodCall, @NonNull result: Result) {
    val privacyValue = call.argument("privacyValue") as String?
      ?: return result.error("ERROR", "usPrivacy is null", null)
    Tapjoy.getPrivacyPolicy().usPrivacy = privacyValue
    return result.success(null)
  }

  private fun getUSPrivacy(@NonNull call: MethodCall, @NonNull result: Result) {
    val privacyValue = Tapjoy.getPrivacyPolicy().usPrivacy
    return result.success(privacyValue)
  }

  private fun setUserLevel(@NonNull call: MethodCall, @NonNull result: Result) {
    val userLevel = call.argument("userLevel") as Int?
      ?: return result.error("ERROR", "userLevel is null", null)
    Tapjoy.setUserLevel(userLevel)
    return result.success(null)
  }

  private fun getUserLevel(@NonNull call: MethodCall, @NonNull result: Result) {
    return result.success(Tapjoy.getUserLevel())
  }

  private fun setMaxLevel(@NonNull call: MethodCall, @NonNull result: Result) {
    val maxUserLevel = call.argument("maxUserLevel") as Int?
      ?: return result.error("ERROR", "maxUserLevel is null", null)
    Tapjoy.setMaxLevel(maxUserLevel)
    return result.success(null)
  }

  private fun getMaxLevel(@NonNull call: MethodCall, @NonNull result: Result) {
    return result.success(Tapjoy.getMaxLevel())
  }

  private fun setUserSegment(@NonNull call: MethodCall, @NonNull result: Result) {
    val userSegmentValue = call.argument("userSegment") as Int?
      ?: return result.error("ERROR", "userSegment is null", null)
    Tapjoy.setUserSegment(TJSegment.valueOf(userSegmentValue))
    return result.success(null)
  }

  private fun getUserSegment(@NonNull call: MethodCall, @NonNull result: Result) {
    return result.success(Tapjoy.getUserSegment().value)
  }

  private fun setUserTags(@NonNull call: MethodCall, @NonNull result: Result) {
    val userTags = call.argument("userTags") as List<String>?
      ?: return result.error("ERROR", "userTags is null", null)
    Tapjoy.setUserTags(userTags.toSet())
    return result.success(null)
  }

  private fun getUserTags(@NonNull call: MethodCall, @NonNull result: Result) {
    return result.success(Tapjoy.getUserTags().toTypedArray())
  }

  private fun clearUserTags(@NonNull call: MethodCall, @NonNull result: Result) {
    Tapjoy.clearUserTags()
    return result.success(null)
  }

  private fun addUserTag(@NonNull call: MethodCall, @NonNull result: Result) {
    val userTag = call.argument("userTag") as String?
      ?: return result.error("ERROR", "userTag is null", null)
    Tapjoy.addUserTag(userTag)
    return result.success(null)
  }

  private fun removeUserTag(@NonNull call: MethodCall, @NonNull result: Result) {
    val userTag = call.argument("userTag") as String?
      ?: return result.error("ERROR", "userTag is null", null)
    Tapjoy.removeUserTag(userTag)
    return result.success(null)
  }

  private fun optOutAdvertisingID(@NonNull call: MethodCall, @NonNull result: Result) {
    if (activity == null) {
      return result.error("ERROR", "Activity is null", null)
    }
    var isOptOut = call.argument<Boolean?>("optOut") ?: false
    Tapjoy.optOutAdvertisingID(activity!!.applicationContext, isOptOut)
    return result.success(null)
  }

  private fun getOptOutAdvertisingID(@NonNull call: MethodCall, @NonNull result: Result) {
    if (activity == null) {
      return result.error("ERROR", "Activity is null", null)
    }
    return result.success(Tapjoy.getOptOutAdvertisingID(activity!!.applicationContext))
  }

  private fun trackPurchase(@NonNull call: MethodCall, @NonNull result: Result) {
    var currencyName = call.argument<String?>("currencyCode") ?: return result.error("ERROR", "currencyCode is null", null)
    var price = call.argument<Double?>("price") ?: return result.error("ERROR", "price is null", null)
    Tapjoy.trackPurchase(currencyName, price)
    return result.success(null)
  }

  private fun getPlacement(@NonNull call: MethodCall, @NonNull result: Result) {
    val placementName = call.argument("placementName") as String?
      ?: return result.error("ERROR", "placementName is null", null)
    val placement = Tapjoy.getPlacement(placementName, this)
    placementMap[placementName] = placement
    return result.success(null)
  }

  private fun requestContent(@NonNull call: MethodCall, @NonNull result: Result) {
    val placementName = call.argument("placementName") as String?
      ?: return result.error("ERROR", "placementName is null", null)
    placementMap[placementName]?.requestContent()
    return result.success(null)
  }

  private fun showContent(@NonNull call: MethodCall, @NonNull result: Result) {
    val placementName = call.argument("placementName") as String?
      ?: return result.error("ERROR", "placementName is null", null)
    placementMap[placementName]?.showContent()
    return result.success(null)
  }

  private fun isContentReady(@NonNull call: MethodCall, @NonNull result: Result) {
    val placementName = call.argument("placementName") as String?
      ?: return result.error("ERROR", "placementName is null", null)
    val contentReady = placementMap[placementName]?.isContentReady
    return result.success(contentReady == true)
  }

  private fun isContentAvailable(@NonNull call: MethodCall, @NonNull result: Result) {
    val placementName = call.argument("placementName") as String?
      ?: return result.error("ERROR", "placementName is null", null)
    val contentAvailable = placementMap[placementName]?.isContentAvailable
    return result.success(contentAvailable == true)
  }

  private fun setEntryPoint(@NonNull call: MethodCall, @NonNull result: Result) {
    val placementName = call.argument("placementName") as String?
      ?: return result.error("ERROR", "placementName is null", null)
    val entryPointValue = call.argument("entryPoint") as Int?
      ?: return result.error("ERROR", "entryPoint is null", null)
    placementMap[placementName]?.entryPoint = TJEntryPoint.fromOrdinal(entryPointValue)
    return result.success(null)
  }

  private fun getEntryPoint(@NonNull call: MethodCall, @NonNull result: Result) {
    val placementName = call.argument("placementName") as String?
      ?: return result.error("ERROR", "placementName is null", null)
    return result.success(placementMap[placementName]?.entryPoint?.ordinal)
  }

  private fun setCurrencyBalance(@NonNull call: MethodCall, @NonNull result: Result) {
    val placementName = call.argument("placementName") as String?
      ?: return result.error("ERROR", "placementName is null", null)
    val currencyId = call.argument("currencyId") as String?
      ?: return result.error("ERROR", "currencyId is null", null)
    val balance = call.argument("currencyBalance") as? Int?
      ?: return result.error("ERROR", "currencyBalance is null", null)
    placementMap[placementName]?.setCurrencyBalance(currencyId, balance, object: TJSetCurrencyBalanceListener {
      override fun onSetCurrencyBalanceSuccess() {
        val successCallback = call.argument("successCallback") as String?
          ?: return result.error("ERROR", "successCallback is null", null)
        ChannelManager.invokeChannelMethod(channelName,
          successCallback,
          placementName
        )
        return result.success(null)
      }

      override fun onSetCurrencyBalanceFailure(code: Int, message: String?) {
        val failureCallback = call.argument("failureCallback") as String?
          ?: return result.error("ERROR", "failureCallback is null", null)
        ChannelManager.invokeChannelMethod(channelName,
          failureCallback,
          hashMapOf( "placementName" to placementName, "error" to message)
        )
        return result.success(null)
      }
    })
  }

  private fun setRequiredAmount(@NonNull call: MethodCall, @NonNull result: Result) {
    val placementName = call.argument("placementName") as String?
      ?: return result.error("ERROR", "placementName is null", null)
    val currencyId = call.argument("currencyId") as String?
      ?: return result.error("ERROR", "currencyId is null", null)
    val amountRequired = call.argument("requiredAmount") as? Int?
      ?: return result.error("ERROR", "requiredAmount is null", null)
    placementMap[placementName]?.setCurrencyAmountRequired(currencyId, amountRequired, object: TJSetCurrencyAmountRequiredListener {
      override fun onSetCurrencyAmountRequiredSuccess() {
        val successCallback = call.argument("successCallback") as String?
          ?: return result.error("ERROR", "successCallback is null", null)
        ChannelManager.invokeChannelMethod(channelName,
          successCallback,
          placementName
        )
        return result.success(null)
      }

      override fun onSetCurrencyAmountRequiredFailure(code: Int, message: String?) {
        val failureCallback = call.argument("failureCallback") as String?
          ?: return result.error("ERROR", "failureCallback is null", null)
        ChannelManager.invokeChannelMethod(channelName,
          failureCallback,
          hashMapOf( "placementName" to placementName, "error" to message)
        )
        return result.success(null)
      }
    })
  }
  // endregion

  /** region Listeners Setup =====================================================================*/
  private fun setListeners() {
    mConnectListener = object: TJConnectListener(){
      override fun onConnectSuccess() {
        ChannelManager.invokeChannelMethod(channelName, "TapjoyOnConnectSuccess", null)
      }
      override fun onConnectFailure(code: Int, message: String?) {
        ChannelManager.invokeChannelMethod(channelName, "TapjoyOnConnectFailure", hashMapOf( "code" to code, "message" to message ))
      }
      override fun onConnectWarning(code: Int, message: String?) {
        ChannelManager.invokeChannelMethod(channelName, "TapjoyOnConnectWarning", hashMapOf( "code" to code, "message" to message ))
      }
    }
  }
  // endregion

  /** region TJPlacementListener =================================================================*/
  override fun onRequestSuccess(placement: TJPlacement?) {
    if (placement == null) {
      Log.e(TAG, "onRequestSuccess: placement is null")
      return
    }
    ChannelManager.invokeChannelMethod(channelName,
      "onRequestSuccess",
      placement.name
    )
  }

  override fun onRequestFailure(placement: TJPlacement?, error: TJError?) {
    if (placement == null) {
      Log.e(TAG, "onRequestFailure: placement is null")
      return
    }
    ChannelManager.invokeChannelMethod(channelName,
      "onRequestFailure",
      hashMapOf(
        "placementName" to placement.name,
        "error" to error?.message
      )
    )
  }

  override fun onContentReady(placement: TJPlacement?) {
    if (placement == null) {
      Log.e(TAG, "onContentReady: placement is null")
      return
    }
    ChannelManager.invokeChannelMethod(channelName,
      "onContentReady",
      placement.name
    )
  }

  override fun onContentShow(placement: TJPlacement?) {
    if (placement == null) {
      Log.e(TAG, "onContentShow: placement is null")
      return
    }
    ChannelManager.invokeChannelMethod(channelName,
      "onContentShow",
      placement.name
    )
  }

  override fun onContentDismiss(placement: TJPlacement?) {
    if (placement == null) {
      Log.e(TAG, "onContentDismiss: placement is null")
      return
    }
    ChannelManager.invokeChannelMethod(channelName,
      "onContentDismiss",
      placement.name
    )
  }

  override fun onClick(placement: TJPlacement?) {
    // Nothing to do
  }

  // endregion

  /** region Utils/Extensions ====================================================================*/



  private fun intToTJStatus(intValue: Int): TJStatus {
    return when(intValue) {
      0 -> TJStatus.FALSE
      1 -> TJStatus.TRUE
      else -> TJStatus.UNKNOWN
    }
  }

  private fun tjStatusToNullableInt(status: TJStatus?): Int? {
    return when(status) {
      TJStatus.FALSE -> 0
      TJStatus.TRUE -> 1
      TJStatus.UNKNOWN -> 2
      null -> null
    }
  }

  // endregion

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    ChannelManager.clear()
  }

  /** region ActivityAware =======================================================================*/
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    (activity as? LifecycleOwner)?.lifecycle?.addObserver(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    (activity as? LifecycleOwner)?.lifecycle?.removeObserver(this)
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
    (activity as? LifecycleOwner)?.lifecycle?.addObserver(this)
  }

  override fun onDetachedFromActivity() {
    (activity as? LifecycleOwner)?.lifecycle?.removeObserver(this)
    activity = null
  }

  // endregion
}
