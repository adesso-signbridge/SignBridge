package com.adesso.signbridge

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var signAvatarHandler: SignAvatarMethodHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "com.adesso.signbridge/sign_avatar_view",
                SignAvatarViewFactory(),
            )

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.adesso.signbridge/sign_avatar",
        )
        signAvatarHandler = SignAvatarMethodHandler(channel).also { it.register() }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        signAvatarHandler?.unregister()
        signAvatarHandler = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
