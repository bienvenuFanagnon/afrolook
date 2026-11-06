package com.afrotok.afrotok

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.content.Context
import android.graphics.Matrix
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import androidx.exifinterface.media.ExifInterface
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.face.FaceLandmark
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * Détection de visages pour les filtres de la caméra (photo). Version « non groupée » de ML Kit : le modèle est fourni par les services Google Play,
 * il n'ajoute presque rien à la taille de l'application. Rien n'est envoyé à un serveur : tout se passe sur le téléphone.
 *
 * Méthode `detect` {path} : lit la photo, la redresse selon son orientation EXIF, l'enregistre redressée dans le cache et rend
 * {path, width, height, faces:[{left, top, width, height, leftEye:{x,y}?, rightEye:{x,y}?, nose:{x,y}?}]} (pixels de l'image redressée).
 */
object FaceChannel {
    private const val NAME = "afrolook/faces"
    private const val MAX_SIDE = 1600

    /** Détecteur gardé pour le direct (une image toutes les ~150 ms) : le recréer à chaque image coûterait trop cher. */
    private val live by lazy {
        FaceDetection.getClient(
            FaceDetectorOptions.Builder()
                .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
                .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL)
                .build()
        )
    }

    private fun faceMap(f: com.google.mlkit.vision.face.Face): Map<String, Any> {
        val b = f.boundingBox
        val m = hashMapOf<String, Any>("left" to b.left, "top" to b.top, "width" to b.width(), "height" to b.height())
        f.getLandmark(FaceLandmark.LEFT_EYE)?.position?.let { m["leftEye"] = mapOf("x" to it.x, "y" to it.y) }
        f.getLandmark(FaceLandmark.RIGHT_EYE)?.position?.let { m["rightEye"] = mapOf("x" to it.x, "y" to it.y) }
        f.getLandmark(FaceLandmark.NOSE_BASE)?.position?.let { m["nose"] = mapOf("x" to it.x, "y" to it.y) }
        return m
    }

    fun register(engine: FlutterEngine, context: Context) {
        val cacheDir = context.cacheDir
        MethodChannel(engine.dartExecutor.binaryMessenger, NAME).setMethodCallHandler { call, result ->
            if (call.method == "ensureModule") {
                // Le modèle de visage (ML Kit non groupé) est fourni par les services Google Play : on le fait télécharger AVANT la première détection,
                // sinon elle échoue silencieusement tant que le module n'est pas là (cas d'une application installée hors du Play Store).
                try {
                    val client = ModuleInstall.getClient(context)
                    client.areModulesAvailable(live)
                        .addOnSuccessListener { avail ->
                            if (avail.areModulesAvailable()) {
                                result.success(true)
                            } else {
                                client.installModules(ModuleInstallRequest.newBuilder().addApi(live).build())
                                    .addOnSuccessListener { r -> result.success(r.areModulesAlreadyInstalled() || true) }
                                    .addOnFailureListener { e -> result.error("module_failed", e.message, null) }
                            }
                        }
                        .addOnFailureListener { e -> result.error("module_failed", e.message, null) }
                } catch (e: Throwable) {
                    result.error("module_failed", e.message, null)
                }
                return@setMethodCallHandler
            }
            if (call.method == "detectFrame") {
                // Image de la caméra (NV21) : rend les visages dans l'image REDRESSÉE (rotation appliquée), sans miroir
                val bytes = call.argument<ByteArray>("bytes")
                val w = call.argument<Int>("width")
                val h = call.argument<Int>("height")
                val rot = call.argument<Int>("rotation") ?: 0
                if (bytes == null || w == null || h == null) {
                    result.error("bad_args", "image manquante", null)
                    return@setMethodCallHandler
                }
                try {
                    live.process(InputImage.fromByteArray(bytes, w, h, rot, InputImage.IMAGE_FORMAT_NV21))
                        .addOnSuccessListener { faces ->
                            val upright = rot == 90 || rot == 270
                            result.success(mapOf("width" to (if (upright) h else w), "height" to (if (upright) w else h), "faces" to faces.map { faceMap(it) }))
                        }
                        .addOnFailureListener { e -> result.error("detect_failed", e.message, null) }
                } catch (e: Throwable) {
                    result.error("detect_failed", e.message, null)
                }
                return@setMethodCallHandler
            }
            if (call.method != "detect") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            if (path == null) {
                result.error("bad_args", "path manquant", null)
                return@setMethodCallHandler
            }
            Thread {
                try {
                    val bmp = loadUpright(path)
                    val out = File(cacheDir, "visage_${System.nanoTime()}.jpg")
                    FileOutputStream(out).use { bmp.compress(Bitmap.CompressFormat.JPEG, 92, it) }
                    val detector = FaceDetection.getClient(
                        FaceDetectorOptions.Builder()
                            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
                            .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL)
                            .build()
                    )
                    detector.process(InputImage.fromBitmap(bmp, 0))
                        .addOnSuccessListener { faces ->
                            val list = faces.map { f ->
                                val b = f.boundingBox
                                val m = hashMapOf<String, Any>(
                                    "left" to b.left, "top" to b.top, "width" to b.width(), "height" to b.height()
                                )
                                f.getLandmark(FaceLandmark.LEFT_EYE)?.position?.let { m["leftEye"] = mapOf("x" to it.x, "y" to it.y) }
                                f.getLandmark(FaceLandmark.RIGHT_EYE)?.position?.let { m["rightEye"] = mapOf("x" to it.x, "y" to it.y) }
                                f.getLandmark(FaceLandmark.NOSE_BASE)?.position?.let { m["nose"] = mapOf("x" to it.x, "y" to it.y) }
                                m
                            }
                            detector.close()
                            result.success(mapOf("path" to out.absolutePath, "width" to bmp.width, "height" to bmp.height, "faces" to list))
                        }
                        .addOnFailureListener { e ->
                            detector.close()
                            result.error("detect_failed", e.message, null)
                        }
                } catch (e: Throwable) {
                    result.error("detect_failed", e.message, null)
                }
            }.start()
        }
    }

    /** Photo décodée (côté long limité), puis tournée comme l'indique l'EXIF. */
    private fun loadUpright(path: String): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / sample > MAX_SIDE * 2) sample *= 2
        val raw = BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
            ?: throw IllegalStateException("Photo illisible")
        val degrees = when (ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        val scale = MAX_SIDE.toFloat() / maxOf(raw.width, raw.height)
        val m = Matrix().apply {
            if (degrees != 0f) postRotate(degrees)
            if (scale < 1f) postScale(scale, scale)
        }
        return if (degrees == 0f && scale >= 1f) raw else Bitmap.createBitmap(raw, 0, 0, raw.width, raw.height, m, true)
    }
}
