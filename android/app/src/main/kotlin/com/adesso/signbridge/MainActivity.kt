package com.adesso.signbridge

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var signAvatarHandler: SignAvatarMethodHandler? = null
    private var emergencyCallHandler: EmergencyCallHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "com.adesso.signbridge/sign_avatar_view",
                SignAvatarViewFactory(),
            )

        val avatarChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.adesso.signbridge/sign_avatar",
        )
        signAvatarHandler = SignAvatarMethodHandler(avatarChannel).also { it.register() }

        val emergencyChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EmergencyCallHandler.CHANNEL,
        )
        emergencyCallHandler = EmergencyCallHandler(this, emergencyChannel).also {
            it.register()
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        emergencyCallHandler?.unregister()
        emergencyCallHandler = null
        signAvatarHandler?.unregister()
        signAvatarHandler = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
