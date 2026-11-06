package com.afrotok.afrotok

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
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

    fun register(engine: FlutterEngine, cacheDir: File) {
        MethodChannel(engine.dartExecutor.binaryMessenger, NAME).setMethodCallHandler { call, result ->
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
