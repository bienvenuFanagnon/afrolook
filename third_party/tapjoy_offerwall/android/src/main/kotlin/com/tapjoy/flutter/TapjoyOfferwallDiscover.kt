package com.tapjoy.flutter

import android.content.Context
import com.tapjoy.TJOfferwallDiscoverListener
import com.tapjoy.TJOfferwallDiscoverView
import com.tapjoy.TJError
import androidx.annotation.NonNull
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

class TapjoyOfferwallDiscover: MethodCallHandler {
    private val channelName = "tapjoy_offerwall_discover"
    companion object {
        var offerwallDiscover: TapjoyOfferwallDiscoverNativeView? = null
    }
    fun registerChannel(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val channel = ChannelManager.registerMethodChannel(flutterPluginBinding, channelName)
        channel.setMethodCallHandler { call, result ->
            onMethodCall(call, result)
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "requestOWDContent" -> requestOWDContent(call, result)
            "clearOWDContent" -> clearOWDContent(call, result)
            else -> result.notImplemented()
        }
    }

    private fun requestOWDContent(@NonNull call: MethodCall, @NonNull result: Result) {
        TapjoyOfferwallPlugin.activity?.let {
            val owd = TapjoyOfferwallDiscoverNativeView(it)
            val placementName = call.argument("placementName") as String?
                ?: return result.error("ERROR", "placementName is null", null)
            owd.requestContent(placementName)
            offerwallDiscover = owd
        }
        return result.success(null)
    }

    private fun clearOWDContent(@NonNull call: MethodCall, @NonNull result: Result) {
        offerwallDiscover?.let {
            it.clearOWDContent()
            offerwallDiscover = null
        }
        return result.success(null)
    }
}

class TapjoyOfferwallDiscoverNativeView : TJOfferwallDiscoverView, TJOfferwallDiscoverListener {
    constructor(context: Context) : super(context)

    fun requestContent(placement: String) {
        setListener(this)
        requestContent(context, placement)
    }

    fun clearOWDContent() {
        super.clearContent()
    }

    override fun requestSuccess() {
        ChannelManager.sendEvent("requestDidSucceedForView", "Request succeeded for view.")
    }

    override fun requestFailure(error: TJError) {
        ChannelManager.sendError(error.code, "requestDidFailForView", error.message ?: "Request failed.")
    }

    override fun contentReady() {
        ChannelManager.sendEvent("contentIsReadyForView", "Content is ready for view.")
    }

    override fun contentError(error: TJError) {
        ChannelManager.sendError(error.code, "contentErrorForView", error.message ?: "Unknown content error")
    }
}