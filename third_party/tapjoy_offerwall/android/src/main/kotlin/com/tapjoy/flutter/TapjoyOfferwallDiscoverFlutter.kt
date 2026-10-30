package com.tapjoy.flutter

import android.util.Log
import android.content.Context
import android.view.View
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class TapjoyOfferwallDiscoverView(context: Context, id: Int, creationParams: Map<String?, Any?>?) : PlatformView {

    private var view: View = View(context)
    override fun getView(): View {
        return view
    }
    private val localContext = context
    override fun dispose() {}

    init {
        loadOfferwallDiscoverContent()
    }

    fun loadOfferwallDiscoverContent() {
        val localOfferwallDiscover = TapjoyOfferwallDiscover.offerwallDiscover
        if (localOfferwallDiscover != null) {
            view = localOfferwallDiscover
        } else {
            Log.w("TapjoyOfferwallDiscoverFlutter", "Offerwall Discover is null")
        }
    }
}

class TapjoyOfferwallDiscoverViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as Map<String?, Any?>?
        return TapjoyOfferwallDiscoverView(context, viewId, creationParams)
    }
}