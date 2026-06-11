package com.adesso.signbridge

object SignAvatarController {
    private var activeRenderer: SignAvatarRendererView? = null

    fun attach(renderer: SignAvatarRendererView) {
        activeRenderer = renderer
    }

    fun detach(renderer: SignAvatarRendererView) {
        if (activeRenderer === renderer) {
            activeRenderer = null
        }
    }

    fun playSign(signTokenId: String) {
        activeRenderer?.post { activeRenderer?.playSign(signTokenId) }
    }

    fun setIdle() {
        activeRenderer?.post { activeRenderer?.setIdle() }
    }
}
