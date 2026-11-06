package com.afrotok.afrotok

import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.SurfaceTexture
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaRecorder
import android.opengl.EGL14
import android.opengl.EGLExt
import android.opengl.EGLSurface
import android.os.Handler
import android.os.Looper
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.Matrix
import android.os.SystemClock
import android.util.Log
import android.view.Surface
import android.view.View
import androidx.camera.core.AspectRatio
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.SurfaceRequest
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.ImageProcessingOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.abs
import kotlin.math.hypot

/**
 * Moteur maison d'effets de visage (Android), gratuit : CameraX + MediaPipe Face Landmarker (478 points, sur le téléphone) + OpenGL.
 * Première version : aperçu en direct avec déformations (gros yeux, grande bouche, visage fin, gros nez). Réglages d'orientation modifiables pour les essais.
 *
 * Canal `afrolook/face_engine` : setEffect(name), setFront(bool), setOrientation(rotationOffset, mirror), status().
 * Vue native `afrolook/face_engine_view` (à afficher avec la composition hybride de Flutter).
 */
object FaceEngine {
    private const val TAG = "FaceEngine"
    private const val CHANNEL = "afrolook/face_engine"
    private const val VIEW = "afrolook/face_engine_view"

    @Volatile var current: FaceEngineView? = null

    fun register(engine: FlutterEngine, activity: Activity) {
        engine.platformViewsController.registry.registerViewFactory(VIEW, object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
            override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
                val front = (args as? Map<*, *>)?.get("front") as? Boolean ?: true
                return FaceEngineView(activity, front).also { current = it }
            }
        })
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val v = current
            when (call.method) {
                "setEffect" -> { v?.renderer?.effect = call.argument<String>("name") ?: "none"; result.success(null) }
                "setFront" -> { v?.setFront(call.argument<Boolean>("front") ?: true); result.success(null) }
                "setOrientation" -> {
                    v?.renderer?.rotOffset = call.argument<Int>("rotation") ?: 0
                    v?.renderer?.mirror = call.argument<Boolean>("mirror") ?: false
                    result.success(null)
                }
                "status" -> result.success(v?.status() ?: mapOf("running" to false))
                "takePhoto" -> {
                    val path = call.argument<String>("path")
                    if (v == null || path == null) result.error("no_view", "Vue du moteur absente", null) else v.renderer.takePhoto(path) { out -> Handler(Looper.getMainLooper()).post { if (out != null) result.success(out) else result.error("photo_failed", "Photo impossible", null) } }
                }
                "startRecording" -> {
                    val path = call.argument<String>("path")
                    if (v == null || path == null) result.error("no_view", "Vue du moteur absente", null) else v.startRecording(path, call.argument<Boolean>("audio") ?: true) { err -> Handler(Looper.getMainLooper()).post { if (err == null) result.success(null) else result.error("record_failed", err, null) } }
                }
                "stopRecording" -> {
                    if (v == null) result.error("no_view", "Vue du moteur absente", null) else v.stopRecording { out, err -> Handler(Looper.getMainLooper()).post { if (out != null) result.success(out) else result.error("record_failed", err ?: "Enregistrement impossible", null) } }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun log(msg: String) = Log.i(TAG, msg)
}

/** Points du visage (coordonnées normalisées de l'image redressée, y vers le bas), lissés d'une image à l'autre. */
class Landmarks(val x: FloatArray, val y: FloatArray)

class FaceEngineView(private val activity: Activity, private var front: Boolean) : PlatformView {
    val glView = GLSurfaceView(activity)
    val renderer = FaceRenderer()
    private var landmarker: FaceLandmarker? = null
    private var provider: ProcessCameraProvider? = null
    private val analysisExecutor = Executors.newSingleThreadExecutor()
    @Volatile private var framesAnalysed = 0
    @Volatile private var lastError: String? = null

    init {
        glView.setEGLContextClientVersion(2)
        // configuration EGL 8 bits par canal et « enregistrable » : le même contexte sert à dessiner aussi dans l'encodeur vidéo
        glView.setEGLConfigChooser { egl, display ->
            val attrs = intArrayOf(EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8, EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT, 0x3142 /* EGL_RECORDABLE_ANDROID */, 1, EGL14.EGL_NONE)
            val cfgs = arrayOfNulls<EGLConfig>(1)
            val n = IntArray(1)
            if (!egl.eglChooseConfig(display, attrs, cfgs, 1, n) || n[0] == 0) {
                val basic = intArrayOf(EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8, EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT, EGL14.EGL_NONE)
                egl.eglChooseConfig(display, basic, cfgs, 1, n)
            }
            cfgs[0]
        }
        glView.setRenderer(renderer)
        glView.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
        renderer.front = front
        initLandmarker()
        startCamera()
    }

    override fun getView(): View = glView

    override fun dispose() {
        try { provider?.unbindAll() } catch (_: Throwable) {}
        try { landmarker?.close() } catch (_: Throwable) {}
        analysisExecutor.shutdown()
        if (FaceEngine.current === this) FaceEngine.current = null
    }

    fun status(): Map<String, Any?> = mapOf("running" to true, "frames" to framesAnalysed, "face" to (renderer.landmarks != null), "error" to lastError, "rotation" to renderer.rotTotal(), "mirror" to renderer.mirrorTotal())

    private var audioRec: MediaRecorder? = null
    private var tmpVideo: String? = null
    private var tmpAudio: String? = null
    private var finalPath: String? = null

    /** Démarre l'enregistrement : la vidéo (avec les effets) est dessinée dans l'encodeur ; le son est enregistré à part puis réuni à la fin. */
    fun startRecording(path: String, audio: Boolean, done: (String?) -> Unit) {
        finalPath = path
        tmpVideo = "$path.video.mp4"
        tmpAudio = if (audio) "$path.audio.m4a" else null
        if (audio) {
            try {
                audioRec = MediaRecorder().apply {
                    setAudioSource(MediaRecorder.AudioSource.MIC)
                    setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                    setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                    setAudioEncodingBitRate(128000)
                    setAudioSamplingRate(44100)
                    setOutputFile(tmpAudio)
                    prepare()
                    start()
                }
            } catch (e: Throwable) {
                audioRec = null; tmpAudio = null   // pas de micro : la vidéo est enregistrée sans son
                FaceEngine.log("Micro indisponible : ${e.message}")
            }
        }
        renderer.startRecording(tmpVideo!!, done)
    }

    fun stopRecording(done: (String?, String?) -> Unit) {
        renderer.stopRecording { videoOk, err ->
            try { audioRec?.stop() } catch (_: Throwable) {}
            try { audioRec?.release() } catch (_: Throwable) {}
            audioRec = null
            Thread {
                try {
                    if (!videoOk) { done(null, err); return@Thread }
                    mux(tmpVideo!!, tmpAudio, finalPath!!)
                    java.io.File(tmpVideo!!).delete()
                    tmpAudio?.let { java.io.File(it).delete() }
                    done(finalPath, null)
                } catch (e: Throwable) { done(null, "assemblage : ${e.message}") }
            }.start()
        }
    }

    /** Réunit la vidéo et le son (deux fichiers terminés) dans un seul MP4, sans réencoder. */
    private fun mux(video: String, audio: String?, out: String) {
        val muxer = MediaMuxer(out, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val ve = MediaExtractor().apply { setDataSource(video) }
        val vIdx = (0 until ve.trackCount).first { ve.getTrackFormat(it).getString(MediaFormat.KEY_MIME)!!.startsWith("video/") }
        ve.selectTrack(vIdx)
        val vTrack = muxer.addTrack(ve.getTrackFormat(vIdx))
        var ae: MediaExtractor? = null
        var aTrack = -1
        if (audio != null && java.io.File(audio).length() > 0) {
            try {
                val e = MediaExtractor().apply { setDataSource(audio) }
                val aIdx = (0 until e.trackCount).firstOrNull { e.getTrackFormat(it).getString(MediaFormat.KEY_MIME)!!.startsWith("audio/") }
                if (aIdx != null) { e.selectTrack(aIdx); aTrack = muxer.addTrack(e.getTrackFormat(aIdx)); ae = e }
            } catch (_: Throwable) { ae = null }
        }
        muxer.start()
        fun copy(ex: MediaExtractor, track: Int) {
            val buf = ByteBuffer.allocate(1 shl 20)
            val info = MediaCodec.BufferInfo()
            while (true) {
                val size = ex.readSampleData(buf, 0)
                if (size < 0) break
                info.set(0, size, ex.sampleTime, if (ex.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0)
                muxer.writeSampleData(track, buf, info)
                ex.advance()
            }
        }
        copy(ve, vTrack)
        if (ae != null && aTrack >= 0) copy(ae, aTrack)
        muxer.stop(); muxer.release(); ve.release(); ae?.release()
    }

    fun setFront(f: Boolean) {
        front = f
        renderer.front = f
        startCamera()
    }

    private fun initLandmarker() {
        try {
            val opts = FaceLandmarker.FaceLandmarkerOptions.builder()
                .setBaseOptions(BaseOptions.builder().setModelAssetPath("face_landmarker.task").build())
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setNumFaces(1)
                .setMinFaceDetectionConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .setResultListener { r: FaceLandmarkerResult, _ -> onResult(r) }
                .setErrorListener { e -> lastError = e.message; FaceEngine.log("MediaPipe : ${e.message}") }
                .build()
            landmarker = FaceLandmarker.createFromOptions(activity, opts)
        } catch (e: Throwable) {
            lastError = "initialisation : ${e.message}"
            FaceEngine.log(lastError!!)
        }
    }

    private fun onResult(r: FaceLandmarkerResult) {
        val faces = r.faceLandmarks()
        if (faces.isEmpty()) { renderer.landmarks = null; return }
        val pts = faces[0]
        val n = pts.size
        val xs = FloatArray(n) { pts[it].x() }
        val ys = FloatArray(n) { pts[it].y() }
        val old = renderer.landmarks
        if (old != null && old.x.size == n) {
            // lissage (moins de tremblements)
            for (i in 0 until n) { xs[i] = old.x[i] * 0.45f + xs[i] * 0.55f; ys[i] = old.y[i] * 0.45f + ys[i] * 0.55f }
        }
        renderer.landmarks = Landmarks(xs, ys)
    }

    private fun analyze(img: ImageProxy) {
        try {
            val lm = landmarker
            if (lm == null) return
            val bmp = img.toBitmap()
            val rot = img.imageInfo.rotationDegrees
            val mp = BitmapImageBuilder(bmp).build()
            lm.detectAsync(mp, ImageProcessingOptions.builder().setRotationDegrees(rot).build(), SystemClock.uptimeMillis())
            framesAnalysed++
        } catch (e: Throwable) {
            lastError = "analyse : ${e.message}"
        } finally {
            img.close()
        }
    }

    private fun startCamera() {
        val future = ProcessCameraProvider.getInstance(activity)
        future.addListener({
            try {
                val p = future.get()
                provider = p
                p.unbindAll()
                val selector = if (front) CameraSelector.DEFAULT_FRONT_CAMERA else CameraSelector.DEFAULT_BACK_CAMERA
                val preview = Preview.Builder().setTargetAspectRatio(AspectRatio.RATIO_4_3).setTargetRotation(Surface.ROTATION_0).build()
                preview.setSurfaceProvider(ContextCompat.getMainExecutor(activity)) { req -> renderer.onSurfaceRequest(req) }
                val analysis = ImageAnalysis.Builder()
                    .setTargetAspectRatio(AspectRatio.RATIO_4_3)
                    .setTargetRotation(Surface.ROTATION_0)
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                    .build()
                analysis.setAnalyzer(analysisExecutor) { analyze(it) }
                p.bindToLifecycle(activity as LifecycleOwner, selector, preview, analysis)
            } catch (e: Throwable) {
                lastError = "caméra : ${e.message}"
                FaceEngine.log(lastError!!)
            }
        }, ContextCompat.getMainExecutor(activity))
    }
}

class FaceRenderer : GLSurfaceView.Renderer {
    @Volatile var landmarks: Landmarks? = null
    @Volatile var effect: String = "none"
    @Volatile var front: Boolean = true
    @Volatile var rotOffset: Int = 0
    @Volatile var mirror: Boolean = false

    @Volatile private var pending: SurfaceRequest? = null
    @Volatile private var infoRotation = 0
    private var texId = 0
    private var surfaceTexture: SurfaceTexture? = null
    @Volatile private var frameReady = false
    private var program = 0
    private var viewW = 1
    private var viewH = 1
    private var bufW = 480
    private var bufH = 640
    private val st = FloatArray(16)
    private val quad: java.nio.FloatBuffer = ByteBuffer.allocateDirect(8 * 4).order(ByteOrder.nativeOrder()).asFloatBuffer().apply { put(floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f)); position(0) }

    fun rotTotal(): Int = ((infoRotation + rotOffset) % 360 + 360) % 360
    fun mirrorTotal(): Boolean = front != mirror

    fun onSurfaceRequest(req: SurfaceRequest) {
        pending = req
        req.setTransformationInfoListener(java.util.concurrent.Executors.newSingleThreadExecutor()) { info -> infoRotation = info.rotationDegrees }
    }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        val tex = IntArray(1)
        GLES20.glGenTextures(1, tex, 0)
        texId = tex[0]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, texId)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        surfaceTexture = SurfaceTexture(texId).also { it.setOnFrameAvailableListener { frameReady = true } }
        program = buildProgram()
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        viewW = width; viewH = height
        GLES20.glViewport(0, 0, width, height)
    }

    @Volatile private var photoPath: String? = null
    @Volatile private var photoCb: ((String?) -> Unit)? = null
    private var recorder: GlRecorder? = null
    private var recFirstTs = -1L

    fun takePhoto(path: String, cb: (String?) -> Unit) { photoCb = cb; photoPath = path }

    fun startRecording(path: String, done: (String?) -> Unit) {
        val rw = 720
        val rh = (((rw.toFloat() * viewH / viewW) / 2f).toInt() * 2).coerceIn(640, 1600)
        try {
            val r = GlRecorder(path, rw, rh)
            pendingRecorder = r
            recFirstTs = -1L
            done(null)
        } catch (e: Throwable) { done("encodeur : ${e.message}") }
    }

    @Volatile private var pendingRecorder: GlRecorder? = null
    @Volatile private var stopCb: ((Boolean, String?) -> Unit)? = null

    fun stopRecording(cb: (Boolean, String?) -> Unit) { stopCb = cb }

    override fun onDrawFrame(gl: GL10?) {
        val st0 = surfaceTexture ?: return
        pending?.let { req ->
            pending = null
            bufW = req.resolution.width; bufH = req.resolution.height
            st0.setDefaultBufferSize(bufW, bufH)
            val surface = Surface(st0)
            req.provideSurface(surface, java.util.concurrent.Executors.newSingleThreadExecutor()) { surface.release() }
        }
        if (frameReady) { frameReady = false; try { st0.updateTexImage() } catch (_: Throwable) {} }
        st0.getTransformMatrix(st)

        // 1) l'écran
        drawScene(viewW, viewH)

        // 2) une photo demandée : lecture des pixels de l'écran
        val pp = photoPath
        if (pp != null) {
            photoPath = null
            val cb = photoCb
            try {
                val buf = ByteBuffer.allocateDirect(viewW * viewH * 4).order(ByteOrder.nativeOrder())
                GLES20.glReadPixels(0, 0, viewW, viewH, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, buf)
                val w = viewW; val h = viewH
                Thread {
                    try {
                        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                        bmp.copyPixelsFromBuffer(buf)
                        val flip = android.graphics.Matrix().apply { preScale(1f, -1f) }
                        val up = Bitmap.createBitmap(bmp, 0, 0, w, h, flip, true)
                        java.io.FileOutputStream(pp).use { up.compress(Bitmap.CompressFormat.JPEG, 92, it) }
                        cb?.invoke(pp)
                    } catch (e: Throwable) { cb?.invoke(null) }
                }.start()
            } catch (e: Throwable) { cb?.invoke(null) }
        }

        // 3) l'enregistrement : même scène dessinée dans l'encodeur vidéo
        pendingRecorder?.let { r -> pendingRecorder = null; try { r.attachEgl(); recorder = r } catch (e: Throwable) { FaceEngine.log("EGL enregistrement : ${e.message}"); r.release() } }
        val rec = recorder
        if (rec != null) {
            try {
                if (recFirstTs < 0) recFirstTs = st0.timestamp
                rec.drawFrame(st0.timestamp - recFirstTs) { drawScene(rec.w, rec.h) }
            } catch (e: Throwable) { FaceEngine.log("Image enregistrée : ${e.message}") }
            val cb = stopCb
            if (cb != null) {
                stopCb = null
                recorder = null
                val err = rec.finish()
                cb(err == null, err)
            }
        } else {
            val cb = stopCb
            if (cb != null) { stopCb = null; cb(false, "aucun enregistrement en cours") }
        }
    }

    /** Dessine la caméra avec les effets dans une zone de [w] × [h] pixels (l'écran ou l'encodeur). */
    private fun drawScene(w: Int, h: Int) {
        GLES20.glViewport(0, 0, w, h)
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        GLES20.glUseProgram(program)

        // image redressée : dimensions après rotation, puis recadrage au format de la zone (comme CameraPreview en mode « cover »)
        val rot = rotTotal()
        val upW = if (rot % 180 == 0) bufW else bufH
        val upH = if (rot % 180 == 0) bufH else bufW
        val aImg = upW.toFloat() / upH
        val aView = w.toFloat() / h
        val csx = if (aView < aImg) aImg / aView else 1f
        val csy = if (aView < aImg) 1f else aView / aImg

        // matrice « image redressée (y vers le haut) → coordonnées de la texture »
        val m = FloatArray(16)
        val t1 = FloatArray(16); val rm = FloatArray(16); val t2 = FloatArray(16); val tmp = FloatArray(16)
        Matrix.setIdentityM(m, 0)
        // miroir horizontal (caméra avant : l'aperçu est un miroir)
        val mir = FloatArray(16); Matrix.setIdentityM(mir, 0)
        if (mirrorTotal()) { Matrix.translateM(mir, 0, 1f, 0f, 0f); Matrix.scaleM(mir, 0, -1f, 1f, 1f) }
        Matrix.setIdentityM(t1, 0); Matrix.translateM(t1, 0, 0.5f, 0.5f, 0f)
        Matrix.setIdentityM(rm, 0); Matrix.rotateM(rm, 0, rot.toFloat(), 0f, 0f, 1f)
        Matrix.setIdentityM(t2, 0); Matrix.translateM(t2, 0, -0.5f, -0.5f, 0f)
        Matrix.multiplyMM(tmp, 0, t1, 0, rm, 0)
        Matrix.multiplyMM(m, 0, tmp, 0, t2, 0)
        val rotMir = FloatArray(16)
        Matrix.multiplyMM(rotMir, 0, m, 0, mir, 0)
        val fin = FloatArray(16)
        Matrix.multiplyMM(fin, 0, st, 0, rotMir, 0)

        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(program, "uMap"), 1, false, fin, 0)
        GLES20.glUniform2f(GLES20.glGetUniformLocation(program, "uCrop"), csx, csy)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uAspect"), aView)

        // paramètres des déformations (espace d'affichage : y vers le haut, recadrage et miroir appliqués)
        val c = FloatArray(8); val r = FloatArray(4); val s = FloatArray(4)
        val lm = landmarks
        if (lm != null && effect != "none") fillEffect(lm, c, r, s, csx, csy, aView)
        GLES20.glUniform2fv(GLES20.glGetUniformLocation(program, "uC"), 4, c, 0)
        GLES20.glUniform1fv(GLES20.glGetUniformLocation(program, "uR"), 4, r, 0)
        GLES20.glUniform1fv(GLES20.glGetUniformLocation(program, "uS"), 4, s, 0)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, texId)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "uTex"), 0)
        val pos = GLES20.glGetAttribLocation(program, "aPos")
        GLES20.glEnableVertexAttribArray(pos)
        GLES20.glVertexAttribPointer(pos, 2, GLES20.GL_FLOAT, false, 0, quad)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(pos)
    }

    /** Position d'un point du visage dans l'espace d'affichage (0 à 1, y vers le haut). */
    private fun disp(lm: Landmarks, i: Int, csx: Float, csy: Float): FloatArray {
        var x = lm.x[i]
        val y = 1f - lm.y[i]
        if (mirrorTotal()) x = 1f - x
        return floatArrayOf((x - 0.5f) * csx + 0.5f, (y - 0.5f) * csy + 0.5f)
    }

    private fun mid(a: FloatArray, b: FloatArray) = floatArrayOf((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    private fun dist(a: FloatArray, b: FloatArray, aspect: Float) = hypot((a[0] - b[0]) * aspect, a[1] - b[1])

    private fun fillEffect(lm: Landmarks, c: FloatArray, r: FloatArray, s: FloatArray, csx: Float, csy: Float, aspect: Float) {
        if (lm.x.size < 468) return
        fun p(i: Int) = disp(lm, i, csx, csy)
        val eyeA = mid(p(33), p(133)); val eyeB = mid(p(362), p(263))
        val eyeR = dist(p(33), p(133), aspect) * 1.25f
        val mouth = mid(p(13), p(14)); val mouthR = dist(p(61), p(291), aspect) * 0.85f
        val nose = p(1); val noseR = dist(p(129), p(358), aspect) * 0.9f
        val faceC = mid(p(234), p(454)); val faceR = dist(p(234), p(454), aspect) * 0.62f
        when (effect) {
            "bigeyes" -> { set(c, r, s, 0, eyeA, eyeR, 0.55f); set(c, r, s, 1, eyeB, eyeR, 0.55f) }
            "bigmouth" -> set(c, r, s, 2, mouth, mouthR, 0.6f)
            "bignose" -> set(c, r, s, 2, nose, noseR, 0.55f)
            "slimface" -> set(c, r, s, 3, faceC, faceR, 0.25f)
        }
    }

    private fun set(c: FloatArray, r: FloatArray, s: FloatArray, i: Int, centre: FloatArray, radius: Float, strength: Float) {
        c[i * 2] = centre[0]; c[i * 2 + 1] = centre[1]; r[i] = radius; s[i] = strength
    }

    private fun buildProgram(): Int {
        val vs = """
            attribute vec4 aPos;
            varying vec2 vU;
            void main() { gl_Position = aPos; vU = (aPos.xy + 1.0) * 0.5; }
        """.trimIndent()
        val fs = """
            #extension GL_OES_EGL_image_external : require
            precision highp float;
            varying vec2 vU;
            uniform samplerExternalOES uTex;
            uniform mat4 uMap;
            uniform vec2 uCrop;
            uniform float uAspect;
            uniform vec2 uC[4];
            uniform float uR[4];
            uniform float uS[4];
            void main() {
                vec2 p = vU;
                // gonflement local (yeux, bouche, nez) : on échantillonne plus près du centre, donc la zone paraît plus grande
                for (int i = 0; i < 3; i++) {
                    if (uS[i] != 0.0) {
                        vec2 d = p - uC[i];
                        float r = length(vec2(d.x * uAspect, d.y));
                        float R = uR[i];
                        if (r < R) {
                            float q = r / R;
                            float k = 1.0 - uS[i] * (1.0 - q * q);
                            p = uC[i] + d * k;
                        }
                    }
                }
                // visage fin : on rapproche horizontalement les bords du visage du centre
                if (uS[3] != 0.0) {
                    vec2 d = p - uC[3];
                    float fy = 1.0 - clamp(abs(d.y) / (uR[3] * 1.8), 0.0, 1.0);
                    float fx = 1.0 - clamp(abs(d.x * uAspect) / (uR[3] * 1.2), 0.0, 1.0);
                    p.x = uC[3].x + d.x * (1.0 + uS[3] * fy * (0.3 + 0.7 * fx));
                }
                vec2 img = (p - 0.5) / uCrop + 0.5;
                vec4 t = uMap * vec4(img, 0.0, 1.0);
                gl_FragColor = texture2D(uTex, t.xy);
            }
        """.trimIndent()
        val v = compile(GLES20.GL_VERTEX_SHADER, vs)
        val f = compile(GLES20.GL_FRAGMENT_SHADER, fs)
        val prog = GLES20.glCreateProgram()
        GLES20.glAttachShader(prog, v); GLES20.glAttachShader(prog, f)
        GLES20.glLinkProgram(prog)
        val ok = IntArray(1)
        GLES20.glGetProgramiv(prog, GLES20.GL_LINK_STATUS, ok, 0)
        if (ok[0] == 0) FaceEngine.log("Programme GL : ${GLES20.glGetProgramInfoLog(prog)}")
        return prog
    }

    private fun compile(type: Int, src: String): Int {
        val sh = GLES20.glCreateShader(type)
        GLES20.glShaderSource(sh, src)
        GLES20.glCompileShader(sh)
        val ok = IntArray(1)
        GLES20.glGetShaderiv(sh, GLES20.GL_COMPILE_STATUS, ok, 0)
        if (ok[0] == 0) FaceEngine.log("Shader GL : ${GLES20.glGetShaderInfoLog(sh)}")
        return sh
    }
}


/** Encodeur vidéo H.264 alimenté par une surface : la scène OpenGL (caméra + effets) y est dessinée image par image. La vidéo est écrite sans son (réuni ensuite). */
class GlRecorder(path: String, val w: Int, val h: Int) {
    private val encoder: MediaCodec = MediaCodec.createEncoderByType("video/avc")
    private val inputSurface: Surface
    private val muxer = MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    private val info = MediaCodec.BufferInfo()
    private var track = -1
    private var started = false
    private var display = EGL14.EGL_NO_DISPLAY
    private var context = EGL14.EGL_NO_CONTEXT
    private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var frames = 0

    init {
        val fmt = MediaFormat.createVideoFormat("video/avc", w, h).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, 6_000_000)
            setInteger(MediaFormat.KEY_FRAME_RATE, 30)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
        encoder.configure(fmt, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        inputSurface = encoder.createInputSurface()
        encoder.start()
    }

    /** À appeler sur le fil OpenGL : crée la surface d'écriture avec la configuration du contexte courant. */
    fun attachEgl() {
        display = EGL14.eglGetCurrentDisplay()
        context = EGL14.eglGetCurrentContext()
        val id = IntArray(1)
        EGL14.eglQueryContext(display, context, EGL14.EGL_CONFIG_ID, id, 0)
        val cfgs = arrayOfNulls<android.opengl.EGLConfig>(1)
        val n = IntArray(1)
        EGL14.eglChooseConfig(display, intArrayOf(EGL14.EGL_CONFIG_ID, id[0], EGL14.EGL_NONE), 0, cfgs, 0, 1, n, 0)
        eglSurface = EGL14.eglCreateWindowSurface(display, cfgs[0], inputSurface, intArrayOf(EGL14.EGL_NONE), 0)
    }

    fun drawFrame(timestampNs: Long, draw: () -> Unit) {
        val prevDraw = EGL14.eglGetCurrentSurface(EGL14.EGL_DRAW)
        val prevRead = EGL14.eglGetCurrentSurface(EGL14.EGL_READ)
        EGL14.eglMakeCurrent(display, eglSurface, eglSurface, context)
        draw()
        EGLExt.eglPresentationTimeANDROID(display, eglSurface, maxOf(0L, timestampNs))
        EGL14.eglSwapBuffers(display, eglSurface)
        EGL14.eglMakeCurrent(display, prevDraw, prevRead, context)
        frames++
        drain(false)
    }

    private fun drain(end: Boolean) {
        if (end) encoder.signalEndOfInputStream()
        while (true) {
            val i = encoder.dequeueOutputBuffer(info, if (end) 10_000 else 0)
            when {
                i == MediaCodec.INFO_TRY_AGAIN_LATER -> { if (!end) return }
                i == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> { track = muxer.addTrack(encoder.outputFormat); muxer.start(); started = true }
                i >= 0 -> {
                    val buf = encoder.getOutputBuffer(i)
                    if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
                    if (info.size > 0 && started && buf != null) {
                        buf.position(info.offset); buf.limit(info.offset + info.size)
                        muxer.writeSampleData(track, buf, info)
                    }
                    encoder.releaseOutputBuffer(i, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                }
            }
        }
    }

    /** Termine l'enregistrement : rend null si tout va bien, sinon la cause. */
    fun finish(): String? {
        return try {
            if (frames == 0) { release(); return "aucune image enregistrée" }
            drain(true)
            release()
            null
        } catch (e: Throwable) { release(); e.message ?: "erreur d'encodage" }
    }

    fun release() {
        try { encoder.stop() } catch (_: Throwable) {}
        try { encoder.release() } catch (_: Throwable) {}
        try { if (started) muxer.stop() } catch (_: Throwable) {}
        try { muxer.release() } catch (_: Throwable) {}
        try { if (eglSurface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, eglSurface) } catch (_: Throwable) {}
        try { inputSurface.release() } catch (_: Throwable) {}
    }
}
