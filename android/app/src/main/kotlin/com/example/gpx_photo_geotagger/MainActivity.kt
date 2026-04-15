package com.example.gpx_photo_geotagger

import android.content.Intent
import android.net.Uri
import androidx.exifinterface.media.ExifInterface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {
    private val channelName = "gpx_photo_geotagger/exif"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readMetadata" -> handleReadMetadata(call, result)
                    "writeGpsMetadata" -> handleWriteGpsMetadata(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleReadMetadata(call: MethodCall, result: MethodChannel.Result) {
        val source = call.argument<String>("source")
        if (source.isNullOrBlank()) {
            result.error("invalid_source", "Missing photo source", null)
            return
        }

        runCatching {
            withExifInterface(source, writable = false) { exif ->
                val rawOriginalDate = listOf(
                    ExifInterface.TAG_DATETIME_ORIGINAL,
                    ExifInterface.TAG_DATETIME_DIGITIZED,
                    ExifInterface.TAG_DATETIME,
                ).firstNotNullOfOrNull { tag ->
                    exif.getAttribute(tag)?.trim()?.takeIf { value -> value.isNotEmpty() }
                }

                val hasGps = !exif.getAttribute(ExifInterface.TAG_GPS_LATITUDE).isNullOrBlank() &&
                    !exif.getAttribute(ExifInterface.TAG_GPS_LONGITUDE).isNullOrBlank()
                mapOf(
                    "rawOriginalDate" to rawOriginalDate,
                    "hasGps" to hasGps,
                )
            }
        }.onSuccess { payload ->
            result.success(payload)
        }.onFailure { error ->
            result.error("read_failed", error.message, null)
        }
    }

    private fun handleWriteGpsMetadata(call: MethodCall, result: MethodChannel.Result) {
        val source = call.argument<String>("source")
        val latitude = call.argument<Double>("latitude")
        val longitude = call.argument<Double>("longitude")
        val altitude = call.argument<Double>("altitude")
        val gpsDateStamp = call.argument<String>("gpsDateStamp")
        val gpsTimeStamp = call.argument<String>("gpsTimeStamp")

        if (source.isNullOrBlank() || latitude == null || longitude == null) {
            result.error("invalid_args", "Missing source or coordinates", null)
            return
        }

        runCatching {
            withExifInterface(source, writable = true) { exif ->
                exif.setLatLong(latitude, longitude)
                if (altitude != null) {
                    exif.setAltitude(altitude)
                }
                if (!gpsDateStamp.isNullOrBlank()) {
                    exif.setAttribute(ExifInterface.TAG_GPS_DATESTAMP, gpsDateStamp)
                }
                if (!gpsTimeStamp.isNullOrBlank()) {
                    exif.setAttribute(ExifInterface.TAG_GPS_TIMESTAMP, gpsTimeStamp)
                }
                exif.saveAttributes()
            }
        }.onSuccess {
            result.success(null)
        }.onFailure { error ->
            result.error("write_failed", error.message, null)
        }
    }

    private fun <T> withExifInterface(source: String, writable: Boolean, block: (ExifInterface) -> T): T {
        return if (source.startsWith("content://")) {
            val uri = Uri.parse(source)
            takePersistablePermission(uri)
            val mode = if (writable) "rw" else "r"
            contentResolver.openFileDescriptor(uri, mode)?.use { descriptor ->
                block(ExifInterface(descriptor.fileDescriptor))
            } ?: throw IOException("Unable to open file descriptor for URI")
        } else {
            val path = if (source.startsWith("file://")) Uri.parse(source).path else source
            if (path.isNullOrBlank()) {
                throw IOException("Invalid file path")
            }
            block(ExifInterface(path))
        }
    }

    private fun takePersistablePermission(uri: Uri) {
        runCatching {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        }
    }
}
