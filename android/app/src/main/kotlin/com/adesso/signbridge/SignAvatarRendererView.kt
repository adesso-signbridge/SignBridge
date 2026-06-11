package com.adesso.signbridge

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Camera
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.Shader
import android.view.View
import android.view.animation.DecelerateInterpolator
import kotlin.math.cos
import kotlin.math.sin

/**
 * Native 3D-styled signing avatar with human proportions and animated arm poses.
 */
class SignAvatarRendererView(context: Context) : View(context) {
    private val camera = Camera()
    private val projection = Matrix()

    private val skinBase = Color.parseColor("#F2C9A5")
    private val skinShadow = Color.parseColor("#D9A67E")
    private val shirtTop = Color.parseColor("#006EC7")
    private val shirtBottom = Color.parseColor("#004F94")
    private val pantsColor = Color.parseColor("#2D3E50")
    private val hairColor = Color.parseColor("#3D2B1F")
    private val lipColor = Color.parseColor("#C97B63")

    private val skinPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val shirtPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val pantsPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = pantsColor
        style = Paint.Style.FILL
    }
    private val hairPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = hairColor
        style = Paint.Style.FILL
    }
    private val featurePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val outlinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#1A000000")
        style = Paint.Style.STROKE
        strokeWidth = 2f
    }

    private var signTokenId: String = "thinking"
    private var leftUpper = 0f
    private var rightUpper = 0f
    private var leftLower = 0f
    private var rightLower = 0f
    private var animator: ValueAnimator? = null

    fun playSign(signTokenId: String) {
        this.signTokenId = signTokenId
        val target = SignPoseLibrary.pose(signTokenId)
        animator?.cancel()
        val start = floatArrayOf(leftUpper, rightUpper, leftLower, rightLower)
        val end = floatArrayOf(target.leftUpper, target.rightUpper, target.leftLower, target.rightLower)
        animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 480
            interpolator = DecelerateInterpolator()
            addUpdateListener {
                val t = it.animatedValue as Float
                leftUpper = lerp(start[0], end[0], t)
                rightUpper = lerp(start[1], end[1], t)
                leftLower = lerp(start[2], end[2], t)
                rightLower = lerp(start[3], end[3], t)
                invalidate()
            }
            start()
        }
    }

    fun setIdle() {
        playSign("thinking")
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        canvas.drawColor(Color.parseColor("#F8FAFC"))

        val cx = width / 2f
        val baseY = height * 0.92f
        val scale = height / 460f

        camera.save()
        camera.rotateX(-10f)
        camera.rotateY(6f)
        camera.getMatrix(projection)
        camera.restore()
        projection.preTranslate(-cx, -baseY)
        projection.postTranslate(cx, baseY)
        canvas.concat(projection)

        val hipY = baseY - 88f * scale
        val shoulderY = baseY - 168f * scale
        val neckY = baseY - 198f * scale
        val headY = baseY - 248f * scale

        drawLeg(canvas, cx - 14f * scale, hipY, scale, isLeft = true)
        drawLeg(canvas, cx + 14f * scale, hipY, scale, isLeft = false)
        drawTorso(canvas, cx, shoulderY, hipY, scale)
        drawArm(canvas, cx - 38f * scale, shoulderY + 8f * scale, leftUpper, leftLower, scale, isLeft = true)
        drawArm(canvas, cx + 38f * scale, shoulderY + 8f * scale, rightUpper, rightLower, scale, isLeft = false)
        drawNeck(canvas, cx, neckY, scale)
        drawHead(canvas, cx, headY, scale)
    }

    private fun drawTorso(canvas: Canvas, cx: Float, shoulderY: Float, hipY: Float, scale: Float) {
        val top = shoulderY - 6f * scale
        val bottom = hipY
        shirtPaint.shader = LinearGradient(
            cx, top, cx, bottom,
            intArrayOf(shirtTop, shirtBottom),
            null,
            Shader.TileMode.CLAMP,
        )
        canvas.drawRoundRect(
            cx - 34f * scale,
            top,
            cx + 34f * scale,
            bottom,
            22f * scale,
            22f * scale,
            shirtPaint,
        )
        shirtPaint.shader = null
    }

    private fun drawNeck(canvas: Canvas, cx: Float, neckY: Float, scale: Float) {
        setSkinGradient(cx, neckY, 12f * scale)
        canvas.drawRoundRect(
            cx - 10f * scale,
            neckY,
            cx + 10f * scale,
            neckY + 24f * scale,
            8f * scale,
            8f * scale,
            skinPaint,
        )
    }

    private fun drawHead(canvas: Canvas, cx: Float, headY: Float, scale: Float) {
        val headW = 52f * scale
        val headH = 62f * scale

        canvas.drawOval(
            cx - headW * 0.55f,
            headY - headH * 0.15f,
            cx + headW * 0.55f,
            headY + headH * 0.55f,
            hairPaint,
        )

        setSkinGradient(cx, headY, 30f * scale)
        canvas.drawOval(
            cx - headW / 2f,
            headY - headH / 2f,
            cx + headW / 2f,
            headY + headH / 2f,
            skinPaint,
        )
        canvas.drawOval(
            cx - headW / 2f,
            headY - headH / 2f,
            cx + headW / 2f,
            headY + headH / 2f,
            outlinePaint.apply { strokeWidth = 1.5f * scale },
        )

        featurePaint.color = Color.parseColor("#2C241E")
        canvas.drawOval(
            cx - 14f * scale,
            headY - 4f * scale,
            cx - 6f * scale,
            headY + 2f * scale,
            featurePaint,
        )
        canvas.drawOval(
            cx + 6f * scale,
            headY - 4f * scale,
            cx + 14f * scale,
            headY + 2f * scale,
            featurePaint,
        )

        featurePaint.color = Color.parseColor("#C4A484")
        canvas.drawRoundRect(
            cx - 5f * scale,
            headY + 8f * scale,
            cx + 5f * scale,
            headY + 16f * scale,
            3f * scale,
            3f * scale,
            featurePaint,
        )

        featurePaint.color = lipColor
        canvas.drawRoundRect(
            cx - 8f * scale,
            headY + 18f * scale,
            cx + 8f * scale,
            headY + 24f * scale,
            4f * scale,
            4f * scale,
            featurePaint,
        )
    }

    private fun drawLeg(canvas: Canvas, cx: Float, hipY: Float, scale: Float, isLeft: Boolean) {
        val offset = if (isLeft) -1f else 1f
        canvas.drawRoundRect(
            cx - 12f * scale,
            hipY,
            cx + 12f * scale,
            hipY + 78f * scale,
            10f * scale,
            10f * scale,
            pantsPaint,
        )
        setSkinGradient(cx + offset * 2f * scale, hipY + 82f * scale, 10f * scale)
        canvas.drawOval(
            cx - 11f * scale,
            hipY + 74f * scale,
            cx + 11f * scale,
            hipY + 92f * scale,
            skinPaint,
        )
    }

    private fun drawArm(
        canvas: Canvas,
        originX: Float,
        originY: Float,
        upperAngle: Float,
        lowerAngle: Float,
        scale: Float,
        isLeft: Boolean,
    ) {
        val direction = if (isLeft) -1f else 1f
        val upperLen = 50f * scale
        val lowerLen = 44f * scale
        val elbowX = originX + direction * upperLen * sin(Math.toRadians(upperAngle.toDouble())).toFloat()
        val elbowY = originY + upperLen * cos(Math.toRadians(upperAngle.toDouble())).toFloat()
        drawLimb(canvas, originX, originY, elbowX, elbowY, 13f * scale, shirtTop)
        val handX = elbowX + direction * lowerLen * sin(Math.toRadians(lowerAngle.toDouble())).toFloat()
        val handY = elbowY + lowerLen * cos(Math.toRadians(lowerAngle.toDouble())).toFloat()
        drawLimb(canvas, elbowX, elbowY, handX, handY, 11f * scale, skinBase)
        drawHand(canvas, handX, handY, scale, isLeft)
    }

    private fun drawLimb(
        canvas: Canvas,
        x1: Float,
        y1: Float,
        x2: Float,
        y2: Float,
        radius: Float,
        color: Int,
    ) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            style = Paint.Style.FILL
        }
        val angle = Math.toDegrees(
            kotlin.math.atan2((y2 - y1).toDouble(), (x2 - x1).toDouble()),
        ).toFloat()
        val length = kotlin.math.hypot((x2 - x1).toDouble(), (y2 - y1).toDouble()).toFloat()
        canvas.save()
        canvas.translate(x1, y1)
        canvas.rotate(angle + 90f)
        canvas.drawRoundRect(-radius, 0f, radius, length, radius, radius, paint)
        canvas.restore()
    }

    private fun drawHand(canvas: Canvas, x: Float, y: Float, scale: Float, isLeft: Boolean) {
        setSkinGradient(x, y, 12f * scale)
        canvas.drawCircle(x, y, 12f * scale, skinPaint)
        val dir = if (isLeft) -1f else 1f
        for (i in 0..3) {
            canvas.drawRoundRect(
                x + dir * (4f + i * 3f) * scale,
                y - 8f * scale,
                x + dir * (7f + i * 3f) * scale,
                y + 2f * scale,
                2f * scale,
                2f * scale,
                skinPaint,
            )
        }
    }

    private fun setSkinGradient(cx: Float, cy: Float, radius: Float) {
        skinPaint.shader = RadialGradient(
            cx - radius * 0.2f,
            cy - radius * 0.25f,
            radius * 1.4f,
            intArrayOf(skinBase, skinShadow),
            null,
            Shader.TileMode.CLAMP,
        )
    }

    private fun lerp(start: Float, end: Float, t: Float) = start + (end - start) * t

    override fun onDetachedFromWindow() {
        animator?.cancel()
        super.onDetachedFromWindow()
    }
}

private data class SignPose(
    val leftUpper: Float,
    val rightUpper: Float,
    val leftLower: Float,
    val rightLower: Float,
)

private object SignPoseLibrary {
    private val idle = SignPose(-22f, 22f, -28f, 28f)

    fun pose(signTokenId: String): SignPose = when (signTokenId) {
        "hello" -> SignPose(-35f, -125f, -20f, -45f)
        "how" -> SignPose(-70f, -70f, -35f, -35f)
        "you" -> SignPose(-10f, -95f, -15f, -10f)
        "today" -> SignPose(-95f, -35f, -55f, -15f)
        "thank_you" -> SignPose(-55f, -55f, -25f, -25f)
        "please" -> SignPose(-80f, -40f, -40f, -10f)
        "help" -> SignPose(-110f, -20f, -70f, -5f)
        "yes" -> SignPose(-20f, -120f, -10f, -30f)
        "no" -> SignPose(-120f, -120f, -60f, -60f)
        "mike" -> SignPose(-45f, -100f, -25f, -35f)
        else -> idle
    }
}
