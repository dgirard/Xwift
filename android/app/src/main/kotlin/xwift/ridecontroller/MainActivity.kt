package xwift.ridecontroller

import android.content.ContentValues
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity : FlutterActivity() {
    private val channelName = "xwift.ridecontroller/media_store"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "saveToDownloads" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName = call.argument<String>("fileName")
                        val mimeType = call.argument<String>("mimeType") ?: "image/png"
                        if (bytes == null || fileName == null) {
                            result.error("INVALID_ARGS", "bytes and fileName are required", null)
                        } else {
                            try {
                                result.success(saveToDownloads(bytes, fileName, mimeType))
                            } catch (e: Exception) {
                                result.error("SAVE_FAILED", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Saves a file in the public Download folder and makes it visible to
     * the gallery and file managers. Returns where the file is.
     *
     * Android 10+: through MediaStore (no permission needed).
     * Android 9 and below: direct write, WRITE_EXTERNAL_STORAGE being
     * requested by the app beforehand.
     */
    private fun saveToDownloads(bytes: ByteArray, fileName: String, mimeType: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = contentResolver
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IOException("MediaStore refused the file")
            try {
                resolver.openOutputStream(uri)?.use { it.write(bytes) }
                    ?: throw IOException("Cannot write $uri")
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
            return "${Environment.DIRECTORY_DOWNLOADS}/$fileName"
        }

        @Suppress("DEPRECATION")
        val directory = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!directory.exists() && !directory.mkdirs()) {
            throw IOException("Cannot create ${directory.absolutePath}")
        }
        val file = File(directory, fileName)
        file.writeBytes(bytes)
        MediaScannerConnection.scanFile(this, arrayOf(file.absolutePath), arrayOf(mimeType), null)
        return file.absolutePath
    }
}
