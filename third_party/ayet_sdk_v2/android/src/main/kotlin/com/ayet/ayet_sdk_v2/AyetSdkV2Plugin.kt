package com.ayet.ayet_sdk_v2

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.ayet.sdk.AyetSdk
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class AyetSdkV2Plugin : FlutterPlugin, MethodCallHandler, ActivityAware, EventChannel.StreamHandler {
    companion object {
        private const val TAG = "AyetSdkV2Plugin"
    }

    private lateinit var channel: MethodChannel
    private lateinit var logChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var applicationContext: Context? = null
    private var activity: Activity? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ayet_sdk_v2")
        channel.setMethodCallHandler(this)

        logChannel = EventChannel(flutterPluginBinding.binaryMessenger, "ayet_sdk_v2/logs")
        logChannel.setStreamHandler(this)

        applicationContext = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            handleMethodCall(call, result)
        } catch (e: Exception) {
            Log.e(TAG, "Error handling method ${call.method}", e)
            result.error("SDK_ERROR", e.message ?: "Unknown error", e.stackTraceToString())
        }
    }

    private fun handleMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }

            // ==================== Initialization ====================
            "init" -> {
                val context = activity ?: applicationContext
                if (context == null) {
                    result.error("NO_CONTEXT", "No context available", null)
                    return
                }
                val placementId = call.argument<Int>("placementId")
                val externalIdentifier = call.argument<String>("externalIdentifier")
                if (placementId == null || externalIdentifier == null) {
                    result.error("INVALID_ARGS", "placementId and externalIdentifier are required", null)
                    return
                }
                try {
                    AyetSdk.init(context, placementId, externalIdentifier)
                    result.success(null)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in init", e)
                    result.success(null) // Don't crash, just log
                }
            }

            "setDebug" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                try {
                    AyetSdk.setDebug(enabled)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in setDebug", e)
                }
                result.success(null)
            }

            "setFullscreenMode" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                try {
                    AyetSdk.setFullscreenMode(enabled)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in setFullscreenMode", e)
                }
                result.success(null)
            }

            // ==================== URL Configuration ====================
            "setBaseUrl" -> {
                val url = call.argument<String>("url")
                if (url == null) {
                    result.error("INVALID_ARGS", "url is required", null)
                    return
                }
                try {
                    AyetSdk.setBaseUrl(url)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in setBaseUrl", e)
                }
                result.success(null)
            }

            "setOfferwallBaseUrl" -> {
                val url = call.argument<String>("url")
                if (url == null) {
                    result.error("INVALID_ARGS", "url is required", null)
                    return
                }
                try {
                    AyetSdk.setOfferwallBaseUrl(url)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in setOfferwallBaseUrl", e)
                }
                result.success(null)
            }

            "setRewardStatusBaseUrl" -> {
                val url = call.argument<String>("url")
                if (url == null) {
                    result.error("INVALID_ARGS", "url is required", null)
                    return
                }
                try {
                    AyetSdk.setRewardStatusBaseUrl(url)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in setRewardStatusBaseUrl", e)
                }
                result.success(null)
            }

            "setSurveywallBaseUrl" -> {
                val url = call.argument<String>("url")
                if (url == null) {
                    result.error("INVALID_ARGS", "url is required", null)
                    return
                }
                try {
                    AyetSdk.setSurveywallBaseUrl(url)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in setSurveywallBaseUrl", e)
                }
                result.success(null)
            }

            // ==================== User Properties ====================
            "setAge" -> {
                val age = call.argument<Int>("age")
                if (age == null) {
                    result.error("INVALID_ARGS", "age is required", null)
                    return
                }
                try {
                    AyetSdk.setAge(age)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in setAge", e)
                }
                result.success(null)
            }

            "setGender" -> {
                val genderString = call.argument<String>("gender")
                if (genderString == null) {
                    result.error("INVALID_ARGS", "gender is required", null)
                    return
                }
                val gender = when (genderString) {
                    "MALE" -> AyetSdk.Gender.MALE
                    "FEMALE" -> AyetSdk.Gender.FEMALE
                    "NON_BINARY" -> AyetSdk.Gender.NON_BINARY
                    else -> {
                        result.error("INVALID_ARGS", "Invalid gender value: $genderString", null)
                        return
                    }
                }
                try {
                    AyetSdk.setGender(gender)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in setGender", e)
                }
                result.success(null)
            }

            "setTrackingCustom1" -> {
                val value = call.argument<String>("value")
                if (value == null) {
                    result.error("INVALID_ARGS", "value is required", null)
                    return
                }
                try {
                    AyetSdk.setTrackingCustom1(value)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in setTrackingCustom1", e)
                }
                result.success(null)
            }

            "setTrackingCustom2" -> {
                val value = call.argument<String>("value")
                if (value == null) {
                    result.error("INVALID_ARGS", "value is required", null)
                    return
                }
                try {
                    AyetSdk.setTrackingCustom2(value)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in setTrackingCustom2", e)
                }
                result.success(null)
            }

            "setTrackingCustom3" -> {
                val value = call.argument<String>("value")
                if (value == null) {
                    result.error("INVALID_ARGS", "value is required", null)
                    return
                }
                try {
                    AyetSdk.setTrackingCustom3(value)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in setTrackingCustom3", e)
                }
                result.success(null)
            }

            "setTrackingCustom4" -> {
                val value = call.argument<String>("value")
                if (value == null) {
                    result.error("INVALID_ARGS", "value is required", null)
                    return
                }
                try {
                    AyetSdk.setTrackingCustom4(value)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in setTrackingCustom4", e)
                }
                result.success(null)
            }

            "setTrackingCustom5" -> {
                val value = call.argument<String>("value")
                if (value == null) {
                    result.error("INVALID_ARGS", "value is required", null)
                    return
                }
                try {
                    AyetSdk.setTrackingCustom5(value)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in setTrackingCustom5", e)
                }
                result.success(null)
            }

            // ==================== Display Methods ====================
            "showOfferwall" -> {
                val currentActivity = activity
                if (currentActivity == null) {
                    Log.w(TAG, "showOfferwall: No activity available")
                    result.success(null)
                    return
                }
                val adSlot = call.argument<Any>("adSlot")
                if (adSlot == null) {
                    result.error("INVALID_ARGS", "adSlot is required", null)
                    return
                }
                try {
                    when (adSlot) {
                        is Int -> AyetSdk.showOfferwall(currentActivity, adSlot)
                        is String -> AyetSdk.showOfferwall(currentActivity, adSlot)
                        else -> {
                            result.error("INVALID_ARGS", "adSlot must be an Int or String", null)
                            return
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error in showOfferwall", e)
                }
                result.success(null)
            }

            "showSurveywall" -> {
                val currentActivity = activity
                if (currentActivity == null) {
                    Log.w(TAG, "showSurveywall: No activity available")
                    result.success(null)
                    return
                }
                val adSlot = call.argument<Any>("adSlot")
                if (adSlot == null) {
                    result.error("INVALID_ARGS", "adSlot is required", null)
                    return
                }
                try {
                    when (adSlot) {
                        is Int -> AyetSdk.showSurveywall(currentActivity, adSlot)
                        is String -> AyetSdk.showSurveywall(currentActivity, adSlot)
                        else -> {
                            result.error("INVALID_ARGS", "adSlot must be an Int or String", null)
                            return
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error in showSurveywall", e)
                }
                result.success(null)
            }

            "showRewardStatus" -> {
                val currentActivity = activity
                if (currentActivity == null) {
                    Log.w(TAG, "showRewardStatus: No activity available")
                    result.success(null)
                    return
                }
                try {
                    AyetSdk.showRewardStatus(currentActivity)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in showRewardStatus", e)
                }
                result.success(null)
            }

            // ==================== API Methods ====================
            "getOffers" -> {
                val adSlot = call.argument<Any>("adSlot")
                if (adSlot == null) {
                    result.error("INVALID_ARGS", "adSlot is required", null)
                    return
                }
                try {
                    val callback: (String?) -> Unit = { offers ->
                        try {
                            result.success(offers)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error returning offers result", e)
                        }
                    }
                    when (adSlot) {
                        is Int -> AyetSdk.getOffers(adSlot, callback)
                        is String -> AyetSdk.getOffers(adSlot, callback)
                        else -> {
                            result.error("INVALID_ARGS", "adSlot must be an Int or String", null)
                            return
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error in getOffers", e)
                    result.success(null) // Return null instead of crashing
                }
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        logChannel.setStreamHandler(null)
        eventSink = null
        applicationContext = null
    }

    // ==================== EventChannel.StreamHandler ====================
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        AyetSdk.setLogHandler { level, tag, message ->
            mainHandler.post {
                eventSink?.success(
                    mapOf(
                        "level" to level,
                        "tag" to tag,
                        "message" to message
                    )
                )
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        AyetSdk.setLogHandler(null)
        eventSink = null
    }

    // ==================== ActivityAware ====================
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
