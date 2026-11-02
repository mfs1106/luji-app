package com.luji.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import java.io.File
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingCsv: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "luji/wechat")
            .setMethodCallHandler { call, result ->
                if (call.method == "shareText") {
                    val content = call.argument<String>("text")
                    if (content.isNullOrBlank()) {
                        result.error("invalid", "Text is empty", null)
                    } else {
                        try {
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                setPackage("com.tencent.mm")
                                putExtra(Intent.EXTRA_TEXT, content)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (error: Exception) {
                            result.success(false)
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "luji/files")
            .setMethodCallHandler { call, result ->
                if (call.method == "pickCsv") {
                    if (pendingCsv != null) {
                        result.error("busy", "A file picker is already open", null)
                    } else {
                        pendingCsv = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("text/*", "application/csv", "application/octet-stream"))
                        }
                        startActivityForResult(intent, 7101)
                    }
                } else if (call.method == "backgroundGeofenceAvailable") {
                    result.success(GeoFenceBridge.available(this))
                } else if (call.method == "registerGeofence") {
                    val id = call.argument<Int>("id")
                    val lat = call.argument<Double>("lat")
                    val lon = call.argument<Double>("lon")
                    val radius = call.argument<Double>("radius")
                    val title = call.argument<String>("title")
                    if (id == null || lat == null || lon == null || radius == null || title == null) {
                        result.error("invalid", "Missing geofence details", null)
                    } else {
                        GeoFenceBridge.register(this, id, lat, lon, radius.toFloat(),
                            title, call.argument<String>("body") ?: "") { ok, _ ->
                            result.success(ok)
                        }
                    }
                } else if (call.method == "removeGeofence") {
                    val id = call.argument<Int>("id")
                    if (id == null) result.error("invalid", "Missing id", null)
                    else {
                        GeoFenceBridge.remove(this, id)
                        result.success(true)
                    }
                } else if (call.method == "recognizeCoupon") {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("invalid", "Missing image path", null)
                    } else {
                        try {
                            val image = InputImage.fromFilePath(this, Uri.fromFile(File(path)))
                            val recognizer = TextRecognition.getClient(
                                ChineseTextRecognizerOptions.Builder().build())
                            recognizer.process(image)
                                .addOnSuccessListener { text -> result.success(text.text) }
                                .addOnFailureListener { error -> result.error("ocr_failed", error.message, null) }
                                .addOnCompleteListener { recognizer.close() }
                        } catch (error: Exception) {
                            result.error("ocr_failed", error.message, null)
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    @Deprecated("Uses the Android document picker result callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 7101) return
        val callback = pendingCsv ?: return
        pendingCsv = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            callback.success(null)
            return
        }
        try {
            val uri = data.data!!
            val bytes = contentResolver.openInputStream(uri)?.use { stream ->
                stream.readBytes()
            } ?: throw IllegalStateException("Cannot read file")
            if (bytes.size > 5 * 1024 * 1024) throw IllegalStateException("CSV exceeds 5 MB")
            callback.success(bytes.toString(Charsets.UTF_8))
        } catch (e: Exception) {
            callback.error("read_failed", e.message, null)
        }
    }
}
