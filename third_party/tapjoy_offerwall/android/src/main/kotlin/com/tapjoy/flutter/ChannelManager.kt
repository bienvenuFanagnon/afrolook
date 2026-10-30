package com.tapjoy.flutter
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.FlutterPlugin


object ChannelManager : EventChannel.StreamHandler {

    private val methodChannels = mutableMapOf<String, MethodChannel>()
    private var eventSink: EventChannel.EventSink? = null
    private lateinit var eventChannel: EventChannel
    val TAG = TapjoyOfferwallPlugin::class.java.simpleName

    fun registerMethodChannel(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding, channelName: String): MethodChannel {
        val channel = MethodChannel(flutterPluginBinding.binaryMessenger, channelName)
        methodChannels[channelName] = channel
        return channel
    }

    fun getMethodChannel(channelName: String): MethodChannel?{
        return methodChannels[channelName]
    }

    fun clear() {
        eventSink = null
        methodChannels.clear()
    }

    fun setupEventChannel(eventChannel: EventChannel) {
        ChannelManager.eventChannel = eventChannel
        ChannelManager.eventChannel.setStreamHandler(this)
    }

    fun sendEvent(type: String, value: Any?) {
        Log.d(TAG, "sendEvent called")
        eventSink?.success(mapOf("type" to type, "value" to value))
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        Log.d(TAG, "onListen called")
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        Log.d(TAG, "onCancel called")
    }


    fun sendError(code: Int, message: String, details: String) {
        eventSink?.error(code.toString(), message, details)
    }

    fun teardown() {
        eventChannel.setStreamHandler(null)
    }

    /**
     * Thin wrapper for runOnUiThread and invokeMethod.
     * No success result handling expected for now.
     */
    fun invokeChannelMethod(channelName: String, methodName: String, args: Any? = null) {
        TapjoyOfferwallPlugin.activity?.runOnUiThread {
            val methodChannel = getMethodChannel(channelName)
            methodChannel?.invokeMethod(methodName, args, object : MethodChannel.Result {
                override fun success(result: Any?) {}
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    Log.e(
                        TAG, "Error: invokeMethod $methodName failed "
                            + "errorCode: $errorCode, message: $errorMessage, details: $errorDetails")
                }
                override fun notImplemented() {
                    Log.e(TAG, "Error: invokeMethod $methodName notImplemented")
                }
            })
        }
    }
}