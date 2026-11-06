package com.afrotok.afrotok

import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.opengl.GLUtils
import android.util.Size
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
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
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
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin

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
                return FaceEngineView(activity, front).also { it.renderer.mirror = front; current = it }
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
                "setBeauty" -> {
                    v?.renderer?.beautySmooth = (call.argument<Double>("smooth") ?: 0.0).toFloat()
                    v?.renderer?.beautyBright = (call.argument<Double>("bright") ?: 0.0).toFloat()
                    v?.renderer?.beautyWarm = (call.argument<Double>("warm") ?: 0.0).toFloat()
                    result.success(null)
                }
                "setParticles" -> {
                    // effets d'expression : `trigger` = mouth (bouche ouverte) ou blink (clin d'œil) ; `png` = le petit dessin qui s'envole
                    val bytes = call.argument<ByteArray>("png")
                    v?.renderer?.particleTrigger = call.argument<String>("trigger") ?: "none"
                    if (bytes != null) v?.renderer?.particlePending = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    result.success(null)
                }
                "setLook" -> { v?.renderer?.look = (call.argument<Int>("look") ?: 0).toFloat(); result.success(null) }
                "setOverlay" -> {
                    // image (PNG) posée sur le visage : `anchor` dit où (eyes, top, nose, corner, face, mouth, chin), `size` la taille en largeur de visage
                    val bytes = call.argument<ByteArray>("png")
                    v?.renderer?.overlayAnchor = call.argument<String>("anchor") ?: "none"
                    v?.renderer?.overlaySize = (call.argument<Double>("size") ?: 1.0).toFloat()
                    v?.renderer?.overlayDy = (call.argument<Double>("dy") ?: 0.0).toFloat()
                    if (bytes != null) v?.renderer?.overlayPending = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    result.success(null)
                }
                "setFlipPoints" -> { v?.renderer?.flipPointsX = call.argument<Boolean>("flip") ?: true; result.success(null) }
                "setPoints" -> { v?.renderer?.showPoints = call.argument<Boolean>("show") ?: true; result.success(null) }
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
class Landmarks(val x: FloatArray, val y: FloatArray, val vx: FloatArray, val vy: FloatArray, val t: Long)

class FaceEngineView(private val activity: Activity, private var front: Boolean) : PlatformView {
    val glView = GLSurfaceView(activity)
    val renderer = FaceRenderer()
    private var landmarker: FaceLandmarker? = null
    private var provider: ProcessCameraProvider? = null
    private val analysisExecutor = Executors.newSingleThreadExecutor()
    @Volatile private var framesAnalysed = 0
    private var previewUc: Preview? = null
    private var analysisUc: ImageAnalysis? = null
    private val displayManager = activity.getSystemService(Context.DISPLAY_SERVICE) as android.hardware.display.DisplayManager
    @Suppress("DEPRECATION")
    private fun screenRotation(): Int = activity.windowManager.defaultDisplay.rotation
    // paysage : quand l'écran tourne, la caméra recalcule la rotation de l'image (les points et l'image restent droits)
    private val displayListener = object : android.hardware.display.DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) {}
        override fun onDisplayRemoved(displayId: Int) {}
        override fun onDisplayChanged(displayId: Int) {
            val r = screenRotation()
            previewUc?.targetRotation = r
            analysisUc?.targetRotation = r
        }
    }
    init { displayManager.registerDisplayListener(displayListener, Handler(Looper.getMainLooper())) }

    // --- suivi de qualité et réglage automatique (par visage : tout repart à zéro quand le visage disparaît)
    private var tried = 0          // images envoyées à la détection (fenêtre glissante)
    private var found = 0          // images où un visage a été trouvé
    @Volatile private var detectRate = 0   // % de détection sur les ~3 dernières secondes
    private var windowStart = SystemClock.uptimeMillis()
    @Volatile private var jitter = 0f      // tremblement moyen au repos (en % de la largeur de l'image)
    @Volatile private var predErr = 0f     // erreur moyenne de prévision quand ça bouge (en % de la largeur)
    @Volatile private var alphaBase = 1.5f // fréquence de coupure minimale (Hz) du filtre One Euro, apprise : plus bas = plus stable, plus haut = plus réactif
    private var learnFrames = 0
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
        try { displayManager.unregisterDisplayListener(displayListener) } catch (_: Throwable) {}
        try { provider?.unbindAll() } catch (_: Throwable) {}
        try { landmarker?.close() } catch (_: Throwable) {}
        analysisExecutor.shutdown()
        if (FaceEngine.current === this) FaceEngine.current = null
    }

    @Volatile private var latencyMs = 0L
    @Volatile private var fps = 0
    @Volatile private var usingGpu = false
    private var fpsCount = 0
    private var fpsSince = SystemClock.uptimeMillis()

    fun status(): Map<String, Any?> = mapOf("detectRate" to detectRate, "jitter" to jitter, "predErr" to predErr, "alpha" to alphaBase, "predGain" to renderer.predGain, "learned" to learnFrames, "running" to true, "frames" to framesAnalysed, "face" to (renderer.landmarks != null), "error" to lastError, "rotation" to renderer.rotTotal(), "mirror" to renderer.mirrorTotal(),
        "latencyMs" to latencyMs, "fps" to fps, "gpu" to usingGpu)

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
        renderer.mirror = f   // sens « selfie » par défaut en caméra avant (le bouton Miroir du labo l'inverse)
        startCamera()
    }

    private fun landmarkerOptions(delegate: Delegate) = FaceLandmarker.FaceLandmarkerOptions.builder()
        .setBaseOptions(BaseOptions.builder().setModelAssetPath("face_landmarker.task").setDelegate(delegate).build())
        .setRunningMode(RunningMode.LIVE_STREAM)
        .setNumFaces(1)
        .setMinFaceDetectionConfidence(0.5f)
        .setMinFacePresenceConfidence(0.5f)
        .setMinTrackingConfidence(0.5f)
        .setResultListener { r: FaceLandmarkerResult, _ -> onResult(r) }
        .setErrorListener { e -> lastError = e.message; FaceEngine.log("MediaPipe : ${e.message}") }
        .build()

    private fun initLandmarker() {
        // le processeur graphique va bien plus vite ; s'il n'est pas disponible sur ce téléphone, on retombe sur le processeur
        try {
            landmarker = FaceLandmarker.createFromOptions(activity, landmarkerOptions(Delegate.GPU))
            usingGpu = true
        } catch (e: Throwable) {
            FaceEngine.log("Détection sur GPU impossible (${e.message}) : processeur")
            try {
                landmarker = FaceLandmarker.createFromOptions(activity, landmarkerOptions(Delegate.CPU))
                usingGpu = false
            } catch (e2: Throwable) {
                lastError = "initialisation : ${e2.message}"
                FaceEngine.log(lastError!!)
            }
        }
    }

    private fun updateRate() {
        val now = SystemClock.uptimeMillis()
        if (now - windowStart >= 3000) { detectRate = if (tried > 0) found * 100 / tried else 0; tried = 0; found = 0; windowStart = now }
    }

    /**
     * Apprentissage en direct, propre à chaque visage (aucune donnée n'est gardée ni envoyée) : on mesure sur quelques points clés
     * (1) le tremblement quand le visage est presque immobile et (2) l'erreur de la prévision quand il bouge, puis on règle le lissage :
     * trop de tremblement → lissage plus fort ; prévision qui se trompe → on s'y fie moins ; visage suivi avec retard → plus réactif.
     */
    private fun learn(old: Landmarks, xs: FloatArray, ys: FloatArray, now: Long) {
        val keys = intArrayOf(1, 33, 263, 61, 291, 10, 152)
        val dt = maxOf(0.016f, (now - old.t) / 1000f)
        var move = 0f; var err = 0f
        for (i in keys) {
            if (i >= xs.size) continue
            val dx = xs[i] - old.x[i]; val dy = ys[i] - old.y[i]
            move += hypot(dx, dy)
            val px = old.x[i] + old.vx[i] * dt; val py = old.y[i] + old.vy[i] * dt
            err += hypot(xs[i] - px, ys[i] - py)
        }
        move /= keys.size; err /= keys.size
        learnFrames++
        if (move < 0.004f) {
            // quasi immobile : ce qui bouge encore est du tremblement
            jitter = jitter * 0.9f + move * 100f * 0.1f
            if (jitter > 0.25f) alphaBase = (alphaBase - 0.05f).coerceAtLeast(0.5f)
            else if (jitter < 0.1f) alphaBase = (alphaBase + 0.02f).coerceAtMost(4f)
        } else {
            predErr = predErr * 0.9f + err * 100f * 0.1f
            if (predErr > 0.8f) renderer.predGain = (renderer.predGain - 0.02f).coerceAtLeast(0.3f)
            else if (predErr < 0.3f) renderer.predGain = (renderer.predGain + 0.01f).coerceAtMost(1.2f)
        }
    }

    private fun onResult(r: FaceLandmarkerResult) {
        val faces = r.faceLandmarks()
        tried++
        if (faces.isEmpty()) {
            renderer.landmarks = null
            // visage perdu : on repart d'un réglage neutre pour le prochain visage
            alphaBase = 1.5f; renderer.predGain = 1.0f; learnFrames = 0; jitter = 0f; predErr = 0f
            updateRate()
            return
        }
        found++
        updateRate()
        val pts = faces[0]
        val n = pts.size
        val now = SystemClock.uptimeMillis()
        val old = renderer.landmarks
        val xs = FloatArray(n) { pts[it].x() }
        val ys = FloatArray(n) { pts[it].y() }
        val vx = FloatArray(n)
        val vy = FloatArray(n)
        if (old != null && old.x.size == n) {
            val dt = maxOf(0.016f, (now - old.t) / 1000f)
            // filtre « One Euro » (référence pour le suivi de points) : la coupure monte avec la vitesse du point,
            // donc très stable à l'arrêt et sans retard quand le visage bouge vite
            val twoPi = 6.2831855f
            val aD = 1f / (1f + 1f / (twoPi * 2f * dt))   // lissage de la vitesse (coupure 2 Hz)
            for (i in 0 until n) {
                val rvx = (xs[i] - old.x[i]) / dt
                val rvy = (ys[i] - old.y[i]) / dt
                vx[i] = old.vx[i] + aD * (rvx - old.vx[i])
                vy[i] = old.vy[i] + aD * (rvy - old.vy[i])
                val cutoff = alphaBase + 12f * hypot(vx[i], vy[i])
                val a = 1f / (1f + 1f / (twoPi * cutoff * dt))
                xs[i] = old.x[i] + (xs[i] - old.x[i]) * a
                ys[i] = old.y[i] + (ys[i] - old.y[i]) * a
            }
        }
        if (old != null && old.x.size == n) learn(old, xs, ys, now)
        renderer.landmarks = Landmarks(xs, ys, vx, vy, now)
        latencyMs = now - r.timestampMs()
        fpsCount++
        if (now - fpsSince >= 1000) { fps = fpsCount; fpsCount = 0; fpsSince = now }
    }

    private fun analyze(img: ImageProxy) {
        try {
            val lm = landmarker
            if (lm == null) return
            val raw = img.toBitmap()
            val rot = img.imageInfo.rotationDegrees
            // image redressée ici (rotation dans le sens des aiguilles d'une montre) : les points rendus sont alors exactement ceux de l'image droite
            val bmp = if (rot == 0) raw else Bitmap.createBitmap(raw, 0, 0, raw.width, raw.height, android.graphics.Matrix().apply { postRotate(rot.toFloat()) }, true)
            lm.detectAsync(BitmapImageBuilder(bmp).build(), SystemClock.uptimeMillis())
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
                val preview = Preview.Builder().setTargetAspectRatio(AspectRatio.RATIO_4_3).setTargetRotation(screenRotation()).build()
                preview.setSurfaceProvider(ContextCompat.getMainExecutor(activity)) { req -> renderer.onSurfaceRequest(req) }
                val lowRes = ResolutionSelector.Builder()
                    .setAspectRatioStrategy(AspectRatioStrategy.RATIO_4_3_FALLBACK_AUTO_STRATEGY)
                    .setResolutionStrategy(ResolutionStrategy(Size(480, 360), ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER))
                    .build()
                val analysis = ImageAnalysis.Builder()
                    .setResolutionSelector(lowRes)
                    .setTargetRotation(screenRotation())
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                    .build()
                analysis.setAnalyzer(analysisExecutor) { analyze(it) }
                previewUc = preview; analysisUc = analysis
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
    @Volatile var effect: String = "none"   // une ou plusieurs déformations séparées par des virgules : bigeyes,bigears,...
    @Volatile var front: Boolean = true
    @Volatile var rotOffset: Int = 90   // mesuré sur un Pixel 8 Pro, caméra avant : image droite avec rotation totale 0° et miroir
    // beauté en direct (0 à 1) : peau lissée, lumière, chaleur
    @Volatile var beautySmooth = 0f
    @Volatile var beautyBright = 0f
    @Volatile var beautyWarm = 0f
    @Volatile var particleTrigger = "none"
    @Volatile var particlePending: Bitmap? = null
    private var pTex = 0
    private val pMax = 80
    private val pxs = FloatArray(80); private val pys = FloatArray(80); private val pvx = FloatArray(80); private val pvy = FloatArray(80)
    private val plife = FloatArray(80); private val psize = FloatArray(80)
    private var pn = 0
    private var pLastT = 0L
    private var pAcc = 0f
    private var pWasBlink = false
    private var browBase = 0f
    private var smileBase = 0f
    private val rnd = java.util.Random()
    @Volatile var look = 0f   // 0 aucun, 1 noir et blanc, 2 sépia, 3 vintage, 4 cinéma, 5 néon, 6 pop
    // image posée sur le visage (masque, lunettes, couronne…) qui suit la position, la taille et l'inclinaison de la tête
    @Volatile var overlayPending: Bitmap? = null
    @Volatile var overlayAnchor = "none"
    @Volatile var overlaySize = 1f
    @Volatile var overlayDy = 0f
    private var ovTex = 0
    private var ovProgram = 0
    private val ovBuf: java.nio.FloatBuffer = ByteBuffer.allocateDirect(16 * 4).order(ByteOrder.nativeOrder()).asFloatBuffer()
    @Volatile var predGain: Float = 1.0f   // part de la prévision de mouvement utilisée (réglée en direct)
    @Volatile var flipPointsX: Boolean = true   // mesuré sur Pixel 8 Pro : sans cela, tête à gauche = points à droite
    @Volatile var showPoints: Boolean = false   // points de repère du visage : jamais dans l'application, seulement dans le labo d'essai
    private var ptProgram = 0
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
        ptProgram = buildPointProgram()
        ovProgram = buildOverlayProgram()
        ovTex = 0
        pTex = 0
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

        updateParticles(landmarks)

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

        // les points de repère se dessinent sur l'écran seulement (jamais dans la photo ni la vidéo)
        if (showPoints) drawPoints()

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
        val aImg = uprightAspect()
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
        val c = FloatArray(16); val r = FloatArray(8); val s = FloatArray(8)
        val lm = landmarks
        if (lm != null && effect != "none") fillEffect(lm, c, r, s, csx, csy, aView)
        GLES20.glUniform2fv(GLES20.glGetUniformLocation(program, "uC"), 8, c, 0)
        GLES20.glUniform1fv(GLES20.glGetUniformLocation(program, "uR"), 8, r, 0)
        GLES20.glUniform1fv(GLES20.glGetUniformLocation(program, "uS"), 8, s, 0)
        GLES20.glUniform3f(GLES20.glGetUniformLocation(program, "uBeauty"), beautySmooth, beautyBright, beautyWarm)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uTexel"), 1f / maxOf(bufW, bufH))
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uLook"), look)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, texId)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "uTex"), 0)
        val pos = GLES20.glGetAttribLocation(program, "aPos")
        GLES20.glEnableVertexAttribArray(pos)
        GLES20.glVertexAttribPointer(pos, 2, GLES20.GL_FLOAT, false, 0, quad)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(pos)
        if (lm != null) drawOverlay(lm, csx, csy, aView)
        drawParticles(aView)
    }

    private fun spawnParticle(x: Float, y: Float, vx: Float, vy: Float, size: Float, life: Float) {
        if (pn >= pMax) return
        pxs[pn] = x; pys[pn] = y; pvx[pn] = vx; pvy[pn] = vy; psize[pn] = size; plife[pn] = life
        pn++
    }

    /** Fait vivre les particules (une fois par image) et en crée quand l'expression choisie se produit : bouche ouverte ou clin d'œil. */
    private fun updateParticles(lm: Landmarks?) {
        val now = SystemClock.uptimeMillis()
        val dt = (if (pLastT == 0L) 16L else (now - pLastT).coerceIn(1L, 50L)) / 1000f
        pLastT = now
        var i = 0
        while (i < pn) {
            plife[i] -= dt
            if (plife[i] <= 0f) {
                val l = pn - 1
                pxs[i] = pxs[l]; pys[i] = pys[l]; pvx[i] = pvx[l]; pvy[i] = pvy[l]; psize[i] = psize[l]; plife[i] = plife[l]
                pn--
                continue
            }
            pxs[i] += pvx[i] * dt; pys[i] += pvy[i] * dt
            i++
        }
        val trig = particleTrigger
        if (lm == null || trig == "none" || lm.x.size < 468) { pWasBlink = false; return }
        val aView = viewW.toFloat() / viewH
        val aImg = uprightAspect()
        val csx = if (aView < aImg) aImg / aView else 1f
        val csy = if (aView < aImg) 1f else aView / aImg
        fun p(k: Int) = disp(lm, k, csx, csy)
        val mouthOpen = dist(p(13), p(14), aView) / maxOf(0.001f, dist(p(61), p(291), aView))
        val eyeOpen = (dist(p(159), p(145), aView) / maxOf(0.001f, dist(p(33), p(133), aView)) + dist(p(386), p(374), aView) / maxOf(0.001f, dist(p(362), p(263), aView))) / 2f
        val blink = eyeOpen < 0.13f
        val faceWd = maxOf(0.001f, dist(p(234), p(454), aView))
        val browGap = (dist(p(105), p(159), aView) + dist(p(334), p(386), aView)) / 2f / faceWd
        val smileW = dist(p(61), p(291), aView) / faceWd
        val yaw = kotlin.math.abs(p(1)[0] - (p(234)[0] + p(454)[0]) / 2f) * aView / faceWd   // nez décalé du centre du visage = tête tournée
        if (browBase == 0f) browBase = browGap
        if (smileBase == 0f) smileBase = smileW
        val browsUp = browGap > browBase * 1.18f
        val smiling = smileW > smileBase * 1.10f && mouthOpen < 0.25f
        // la référence (visage au repos) se met à jour doucement quand le geste n'est pas fait
        if (!browsUp) browBase += (browGap - browBase) * 0.02f
        if (!smiling) smileBase += (smileW - smileBase) * 0.02f
        val streamAt: FloatArray? = when {
            trig == "mouth" && mouthOpen > 0.30f -> mid(p(13), p(14))
            trig == "smile" && smiling -> mid(p(13), p(14))
            trig == "brows" && browsUp -> p(10)
            trig == "turn" && yaw > 0.14f -> p(1)
            else -> null
        }
        if (streamAt != null) {
            val m = streamAt
            pAcc += dt * 14f
            while (pAcc >= 1f) {
                pAcc -= 1f
                spawnParticle(m[0] + (rnd.nextFloat() - .5f) * 0.05f, m[1], (rnd.nextFloat() - .5f) * 0.16f, 0.22f + rnd.nextFloat() * 0.22f, 0.05f + rnd.nextFloat() * 0.04f, 1.3f)
            }
        } else if (trig == "blink" && blink && !pWasBlink) {
            val e = mid(p(33), p(263))
            for (k in 0 until 12) {
                val ang = rnd.nextFloat() * 6.2831855f
                val sp = 0.12f + rnd.nextFloat() * 0.25f
                spawnParticle(e[0], e[1], cos(ang) * sp / aView, sin(ang) * sp, 0.04f + rnd.nextFloat() * 0.04f, 0.9f)
            }
        }
        pWasBlink = blink
    }

    private fun drawParticles(aspect: Float) {
        particlePending?.let { bmp ->
            particlePending = null
            if (pTex == 0) { val t = IntArray(1); GLES20.glGenTextures(1, t, 0); pTex = t[0] }
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, pTex)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
            GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bmp, 0)
            bmp.recycle()
        }
        if (pTex == 0 || pn == 0) return
        GLES20.glUseProgram(ovProgram)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_ONE, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, pTex)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(ovProgram, "uOv"), 0)
        val ap = GLES20.glGetAttribLocation(ovProgram, "aP"); val at = GLES20.glGetAttribLocation(ovProgram, "aT")
        for (i in 0 until pn) {
            val s = psize[i]
            val cx = pxs[i]; val cy = pys[i]
            GLES20.glUniform1f(GLES20.glGetUniformLocation(ovProgram, "uAlpha"), minOf(1f, plife[i] / 0.4f))
            ovBuf.clear()
            val ks = arrayOf(floatArrayOf(-.5f, -.5f), floatArrayOf(.5f, -.5f), floatArrayOf(-.5f, .5f), floatArrayOf(.5f, .5f))
            for (k in ks) {
                ovBuf.put((cx + k[0] * s / aspect) * 2f - 1f); ovBuf.put((cy + k[1] * s) * 2f - 1f)
                ovBuf.put(k[0] + .5f); ovBuf.put(.5f - k[1])
            }
            ovBuf.position(0); GLES20.glVertexAttribPointer(ap, 2, GLES20.GL_FLOAT, false, 16, ovBuf); GLES20.glEnableVertexAttribArray(ap)
            ovBuf.position(2); GLES20.glVertexAttribPointer(at, 2, GLES20.GL_FLOAT, false, 16, ovBuf); GLES20.glEnableVertexAttribArray(at)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        }
        GLES20.glDisableVertexAttribArray(ap); GLES20.glDisableVertexAttribArray(at)
        GLES20.glDisable(GLES20.GL_BLEND)
        ovBuf.position(0)
    }

    private fun buildOverlayProgram(): Int {
        val vs = "attribute vec2 aP; attribute vec2 aT; varying vec2 vT; void main() { gl_Position = vec4(aP, 0.0, 1.0); vT = aT; }"
        val fs = "precision mediump float; varying vec2 vT; uniform sampler2D uOv; uniform float uAlpha; void main() { gl_FragColor = texture2D(uOv, vT) * uAlpha; }"
        val prog = GLES20.glCreateProgram()
        GLES20.glAttachShader(prog, compile(GLES20.GL_VERTEX_SHADER, vs))
        GLES20.glAttachShader(prog, compile(GLES20.GL_FRAGMENT_SHADER, fs))
        GLES20.glLinkProgram(prog)
        return prog
    }

    /** Pose l'image du masque sur le visage : position selon l'ancre, taille selon la largeur du visage, inclinaison selon la ligne des yeux. */
    private fun drawOverlay(lm: Landmarks, csx: Float, csy: Float, aspect: Float) {
        overlayPending?.let { bmp ->
            overlayPending = null
            if (ovTex == 0) { val t = IntArray(1); GLES20.glGenTextures(1, t, 0); ovTex = t[0] }
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, ovTex)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
            GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bmp, 0)
            bmp.recycle()
        }
        val anchor = overlayAnchor
        if (ovTex == 0 || anchor == "none" || lm.x.size < 468) return
        fun p(i: Int) = disp(lm, i, csx, csy)
        val e1 = p(33); val e2 = p(263)
        val a = if (e1[0] <= e2[0]) e1 else e2
        val b = if (e1[0] <= e2[0]) e2 else e1
        val theta = atan2(b[1] - a[1], (b[0] - a[0]) * aspect)   // inclinaison de la tête
        val faceW = dist(p(234), p(454), aspect)
        val faceH = dist(p(10), p(152), aspect)
        val faceC = mid(mid(p(234), p(454)), mid(p(10), p(152)))
        val c = when (anchor) {
            "eyes" -> mid(a, b)
            "top" -> p(10)
            "nose" -> p(1)
            "corner" -> floatArrayOf(p(454)[0].coerceAtLeast(p(234)[0]), p(10)[1])
            "mouth" -> mid(p(13), p(14))
            "chin" -> p(152)
            else -> floatArrayOf(faceC[0], faceC[1] + faceH * 0.04f)   // « face » : tout le visage
        }
        val size = faceW * overlaySize
        val cy = c[1] + faceH * overlayDy
        val cs = cos(theta); val sn = sin(theta)
        val corners = arrayOf(floatArrayOf(-.5f, -.5f), floatArrayOf(.5f, -.5f), floatArrayOf(-.5f, .5f), floatArrayOf(.5f, .5f))
        ovBuf.clear()
        for (k in corners) {
            val lx = k[0] * size; val ly = k[1] * size
            val rx = lx * cs - ly * sn; val ry = lx * sn + ly * cs
            ovBuf.put((c[0] + rx / aspect) * 2f - 1f); ovBuf.put(cy + ry).also { }   // y corrigé ci-dessous
            ovBuf.put(k[0] + .5f); ovBuf.put(.5f - k[1])
        }
        // (y en espace d'affichage 0 à 1 → -1 à 1)
        for (i in 0 until 4) ovBuf.put(i * 4 + 1, ovBuf.get(i * 4 + 1) * 2f - 1f)
        GLES20.glUseProgram(ovProgram)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(ovProgram, "uAlpha"), 1f)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_ONE, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, ovTex)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(ovProgram, "uOv"), 0)
        val ap = GLES20.glGetAttribLocation(ovProgram, "aP"); val at = GLES20.glGetAttribLocation(ovProgram, "aT")
        ovBuf.position(0); GLES20.glVertexAttribPointer(ap, 2, GLES20.GL_FLOAT, false, 16, ovBuf); GLES20.glEnableVertexAttribArray(ap)
        ovBuf.position(2); GLES20.glVertexAttribPointer(at, 2, GLES20.GL_FLOAT, false, 16, ovBuf); GLES20.glEnableVertexAttribArray(at)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(ap); GLES20.glDisableVertexAttribArray(at)
        GLES20.glDisable(GLES20.GL_BLEND)
        ovBuf.position(0)
    }

    /**
     * Format (largeur ÷ hauteur) de l'image REDRESSÉE. Il dépend de la vraie rotation de la caméra (90° ou 270° sur un téléphone tenu droit : l'image
     * du capteur est couchée, donc la redressée est plus haute que large), jamais des boutons d'essai « Tourner » qui ne font que choisir le sens.
     */
    private fun uprightAspect(): Float {
        val sideways = infoRotation % 180 != 0
        val upW = if (sideways) bufH else bufW
        val upH = if (sideways) bufW else bufH
        return upW.toFloat() / upH
    }

    /** Recadrage (comme dans drawScene) pour une zone de [w] × [h] pixels. */
    private fun crop(w: Int, h: Int): FloatArray {
        val aImg = uprightAspect()
        val aView = w.toFloat() / h
        return floatArrayOf(if (aView < aImg) aImg / aView else 1f, if (aView < aImg) 1f else aView / aImg)
    }

    /** Dessine les points du visage : les 478 en petits points jaunes, puis yeux, nez et bouche en gros points de couleur. */
    private fun drawPoints() {
        val lm = landmarks ?: return
        val n = lm.x.size
        if (n < 468) return
        GLES20.glViewport(0, 0, viewW, viewH)
        val c = crop(viewW, viewH)
        fun put(buf: FloatArray, k: Int, i: Int) { val p = disp(lm, i, c[0], c[1]); buf[k * 2] = p[0] * 2f - 1f; buf[k * 2 + 1] = p[1] * 2f - 1f }
        fun draw(idx: IntArray, size: Float, r: Float, g: Float, b: Float) {
            val arr = FloatArray(idx.size * 2)
            for (k in idx.indices) put(arr, k, idx[k])
            val fb = ByteBuffer.allocateDirect(arr.size * 4).order(ByteOrder.nativeOrder()).asFloatBuffer().apply { put(arr); position(0) }
            GLES20.glUseProgram(ptProgram)
            GLES20.glUniform1f(GLES20.glGetUniformLocation(ptProgram, "uSize"), size)
            GLES20.glUniform4f(GLES20.glGetUniformLocation(ptProgram, "uCol"), r, g, b, 1f)
            val pos = GLES20.glGetAttribLocation(ptProgram, "aP")
            GLES20.glEnableVertexAttribArray(pos)
            GLES20.glVertexAttribPointer(pos, 2, GLES20.GL_FLOAT, false, 0, fb)
            GLES20.glDrawArrays(GLES20.GL_POINTS, 0, idx.size)
            GLES20.glDisableVertexAttribArray(pos)
        }
        draw(IntArray(minOf(n, 478)) { it }, 7f, 1f, 0.85f, 0f)                    // tous les points : jaune
        draw(intArrayOf(33, 133, 362, 263), 20f, 0f, 0.9f, 1f)                     // coins des yeux : cyan
        draw(intArrayOf(1), 24f, 1f, 0.2f, 0.2f)                                   // bout du nez : rouge
        draw(intArrayOf(13, 14, 61, 291), 20f, 1f, 0f, 0.8f)                       // bouche : rose
        draw(intArrayOf(234, 454, 10, 152), 20f, 0.3f, 1f, 0.3f)                   // contour du visage : vert
    }

    private fun buildPointProgram(): Int {
        val vs = "attribute vec2 aP; uniform float uSize; void main() { gl_Position = vec4(aP, 0.0, 1.0); gl_PointSize = uSize; }"
        val fs = "precision mediump float; uniform vec4 uCol; void main() { gl_FragColor = uCol; }"
        val v = compile(GLES20.GL_VERTEX_SHADER, vs)
        val f = compile(GLES20.GL_FRAGMENT_SHADER, fs)
        val prog = GLES20.glCreateProgram()
        GLES20.glAttachShader(prog, v); GLES20.glAttachShader(prog, f)
        GLES20.glLinkProgram(prog)
        return prog
    }

    /** Position d'un point du visage dans l'espace d'affichage (0 à 1, y vers le haut). */
    private fun disp(lm: Landmarks, i: Int, csx: Float, csy: Float): FloatArray {
        // le visage se déplace pendant que la détection travaille : on prévoit sa position actuelle d'après sa vitesse (au plus 80 ms)
        val dt = ((SystemClock.uptimeMillis() - lm.t) / 1000f).coerceIn(0f, 0.08f) * predGain
        var x = lm.x[i] + lm.vx[i] * dt
        val y = 1f - (lm.y[i] + lm.vy[i] * dt)
        if (mirrorTotal() != flipPointsX) x = 1f - x
        return floatArrayOf((x - 0.5f) * csx + 0.5f, (y - 0.5f) * csy + 0.5f)
    }

    private fun mid(a: FloatArray, b: FloatArray) = floatArrayOf((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    private fun dist(a: FloatArray, b: FloatArray, aspect: Float) = hypot((a[0] - b[0]) * aspect, a[1] - b[1])

    private fun fillEffect(lm: Landmarks, c: FloatArray, r: FloatArray, s: FloatArray, csx: Float, csy: Float, aspect: Float) {
        if (lm.x.size < 468) return
        fun p(i: Int) = disp(lm, i, csx, csy)
        val a = p(234); val b = p(454)
        val left = if (a[0] <= b[0]) a else b; val right = if (a[0] <= b[0]) b else a
        val eyeA = mid(p(33), p(133)); val eyeB = mid(p(362), p(263))
        val eyeR = dist(p(33), p(133), aspect) * 1.25f
        val mouth = mid(p(13), p(14)); val mouthR = dist(p(61), p(291), aspect) * 0.85f
        val nose = p(1); val noseR = dist(p(129), p(358), aspect) * 0.9f
        val faceC = mid(a, b); val faceW = dist(a, b, aspect); val faceH = dist(p(10), p(152), aspect)
        val faceR = faceW * 0.62f
        // les oreilles : de chaque côté du visage, un peu en dehors du contour, à hauteur des yeux
        val earDx = faceW * 0.14f / aspect
        val earL = floatArrayOf(left[0] - earDx, left[1] + faceH * 0.04f)
        val earR = floatArrayOf(right[0] + earDx, right[1] + faceH * 0.04f)
        val earRad = faceW * 0.30f
        for (name in effect.split(',')) {
            when (name.trim()) {
                "bigeyes" -> { set(c, r, s, 0, eyeA, eyeR, 0.55f); set(c, r, s, 1, eyeB, eyeR, 0.55f) }
                "bigmouth" -> set(c, r, s, 2, mouth, mouthR, 0.6f)
                "bignose" -> set(c, r, s, 3, nose, noseR, 0.55f)
                "bigears" -> { set(c, r, s, 4, earL, earRad, 0.6f); set(c, r, s, 5, earR, earRad, 0.6f) }
                "slimface" -> set(c, r, s, 6, faceC, faceR, 0.25f)
            }
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
            uniform vec2 uC[8];
            uniform float uR[8];
            uniform float uS[8];
            uniform vec3 uBeauty;
            uniform float uTexel;
            uniform float uLook;
            void main() {
                vec2 p = vU;
                // gonflement local (yeux, bouche, nez) : on échantillonne plus près du centre, donc la zone paraît plus grande
                for (int i = 0; i < 6; i++) {
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
                if (uS[6] != 0.0) {
                    vec2 d = p - uC[6];
                    float fy = 1.0 - clamp(abs(d.y) / (uR[6] * 1.8), 0.0, 1.0);
                    float fx = 1.0 - clamp(abs(d.x * uAspect) / (uR[6] * 1.2), 0.0, 1.0);
                    p.x = uC[6].x + d.x * (1.0 + uS[6] * fy * (0.3 + 0.7 * fx));
                }
                vec2 img = (p - 0.5) / uCrop + 0.5;
                vec4 t = uMap * vec4(img, 0.0, 1.0);
                vec4 c = texture2D(uTex, t.xy);
                if (uBeauty.x > 0.0) {
                    // peau lissée : moyenne des voisins, seulement sur les tons de peau et loin des contours (yeux, bouche, cheveux restent nets)
                    vec2 o = vec2(uTexel) * (1.5 + 3.0 * uBeauty.x);
                    vec3 b = c.rgb * 0.25;
                    b += (texture2D(uTex, t.xy + vec2(o.x, 0.0)).rgb + texture2D(uTex, t.xy - vec2(o.x, 0.0)).rgb + texture2D(uTex, t.xy + vec2(0.0, o.y)).rgb + texture2D(uTex, t.xy - vec2(0.0, o.y)).rgb) * 0.125;
                    b += (texture2D(uTex, t.xy + o).rgb + texture2D(uTex, t.xy - o).rgb + texture2D(uTex, t.xy + vec2(o.x, -o.y)).rgb + texture2D(uTex, t.xy + vec2(-o.x, o.y)).rgb) * 0.0625;
                    float cb = -0.169 * c.r - 0.331 * c.g + 0.5 * c.b + 0.5;
                    float cr = 0.5 * c.r - 0.419 * c.g - 0.081 * c.b + 0.5;
                    float skin = smoothstep(0.28, 0.33, cb) * (1.0 - smoothstep(0.48, 0.53, cb)) * smoothstep(0.50, 0.54, cr) * (1.0 - smoothstep(0.66, 0.71, cr));
                    float edge = length(c.rgb - b);
                    float k = uBeauty.x * skin * (1.0 - smoothstep(0.06, 0.16, edge));
                    c.rgb = mix(c.rgb, b, clamp(k * 0.9, 0.0, 1.0));
                }
                c.rgb += vec3(uBeauty.y * 0.10 + uBeauty.z * 0.035, uBeauty.y * 0.10, uBeauty.y * 0.10 - uBeauty.z * 0.035);
                if (uLook > 0.5) {
                    float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
                    if (uLook < 1.5) {
                        c.rgb = vec3(clamp((l - 0.5) * 1.15 + 0.5, 0.0, 1.0));                          // noir et blanc contrasté
                    } else if (uLook < 2.5) {
                        c.rgb = vec3(l * 1.08, l * 0.95, l * 0.74);                                      // sépia
                    } else if (uLook < 3.5) {
                        c.rgb = mix(vec3(l), c.rgb, 0.72) * vec3(1.05, 0.98, 0.90) * 0.92 + 0.07;        // vintage : couleurs fanées, noirs relevés
                    } else if (uLook < 4.5) {
                        vec3 g = mix(c.rgb, vec3(l), 0.18);                                              // cinéma : ombres bleutées, hautes lumières chaudes
                        c.rgb = g + vec3((l - 0.45) * 0.16, (l - 0.45) * 0.02, -(l - 0.45) * 0.16);
                        c.rgb = (c.rgb - 0.5) * 1.08 + 0.5;
                    } else if (uLook < 5.5) {
                        c.rgb = mix(vec3(l), c.rgb, 1.7) * vec3(0.92, 0.82, 1.18);                       // néon
                    } else {
                        c.rgb = (mix(vec3(l), c.rgb, 1.5) - 0.5) * 1.12 + 0.5;                           // pop : couleurs vives
                    }
                }
                gl_FragColor = vec4(clamp(c.rgb, 0.0, 1.0), 1.0);
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
