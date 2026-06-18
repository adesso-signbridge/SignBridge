package com.adesso.signbridge

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class EmergencyCallHandler(
    private val activity: FlutterActivity,
    private val channel: MethodChannel,
) : MethodChannel.MethodCallHandler {

    fun register() {
        channel.setMethodCallHandler(this)
    }

    fun unregister() {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "call" -> {
                val number = call.argument<String>("number")?.trim().orEmpty()
                if (number.isEmpty()) {
                    result.error("invalid_number", "Missing phone number", null)
                    return
                }
                try {
                    val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$number"))
                    activity.startActivity(intent)
                    result.success(true)
                } catch (error: Exception) {
                    result.error("call_failed", error.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL = "com.adesso.signbridge/emergency_call"
    }
}
