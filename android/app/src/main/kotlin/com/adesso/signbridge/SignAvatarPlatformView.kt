package com.adesso.signbridge

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class SignAvatarViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val params = args as? Map<String, Any?>
        val signTokenId = params?.get("signTokenId") as? String ?: "thinking"
        return SignAvatarPlatformView(context, signTokenId)
    }
}

class SignAvatarPlatformView(
    context: Context,
    initialSignTokenId: String,
) : PlatformView {
    private val renderer = SignAvatarRendererView(context)

    init {
        SignAvatarController.attach(renderer)
        if (initialSignTokenId != "thinking") {
            renderer.playSign(initialSignTokenId)
        } else {
            renderer.setIdle()
        }
    }

    override fun getView() = renderer

    override fun dispose() {
        SignAvatarController.detach(renderer)
    }
}

class SignAvatarMethodHandler(private val channel: MethodChannel) :
    MethodChannel.MethodCallHandler {
    fun register() {
        channel.setMethodCallHandler(this)
    }

    fun unregister() {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "playSign" -> {
                val signTokenId = call.argument<String>("signTokenId") ?: "thinking"
                SignAvatarController.playSign(signTokenId)
                result.success(null)
            }
            "setIdle" -> {
                SignAvatarController.setIdle()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
