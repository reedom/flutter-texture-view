package com.reedom.flutter.textureview

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Rect
import android.view.Surface
import io.flutter.view.TextureRegistry
import org.jetbrains.anko.AnkoLogger
import org.jetbrains.anko.warn
import java.util.*
import kotlin.concurrent.schedule

open class BitmapTextureRenderer(private val surfaceTexture: TextureRegistry.SurfaceTextureEntry) {
  private val log = AnkoLogger(this.javaClass)

  private val surface = Surface(surfaceTexture.surfaceTexture())
  private var disposed = false;
  private var renderTask: TimerTask? = null
  private var sizeChanged = false
  private var bitmap: Bitmap? = null

  fun dispose() {
    disposed = true
    renderTask?.cancel()
  }

  val textureID: Long
    get() = surfaceTexture.id()

  fun render(bitmap: Bitmap) {
    sizeChanged = (this.bitmap == null)
      || (this.bitmap?.width != bitmap.width
      || this.bitmap?.height != bitmap.height)
    this.bitmap = bitmap
    renderBitmap()
  }

  private fun renderBitmap(retry: Int = 5) {
    renderTask = null
    if (disposed || bitmap == null) return

    updateBuffer()
    val canvas = lockCanvas()
    if (canvas == null) {
      if (0 < retry) {
        renderTask = Timer("draw", false).schedule(1) { renderBitmap(retry - 1) }
      }
      return
    }

    kotlin.runCatching {
      bitmap?.let { bitmap ->
        val rect = Rect(0, 0, bitmap.width, bitmap.height)
        canvas.drawBitmap(bitmap, rect, rect, null)
      }
      surface.unlockCanvasAndPost(canvas)
    }.onFailure { e -> log.warn("Failed to render: $e") }
  }

  private fun updateBuffer() {
    kotlin.runCatching {
      if (sizeChanged && bitmap != null) {
        sizeChanged = false
        surfaceTexture.surfaceTexture().setDefaultBufferSize(bitmap!!.width, bitmap!!.height)
      }
    }.onFailure { e -> log.warn("Failed to setDefaultBufferSize: $e") }
  }

  private fun lockCanvas(): Canvas? {
    kotlin.runCatching {
      return if (surface.isValid) surface.lockCanvas(null) else null
    }.onFailure { e -> log.warn("Failed to lock canvas: $e") }
    return null
  }
}
