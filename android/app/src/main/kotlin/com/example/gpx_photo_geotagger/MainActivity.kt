package com.example.gpx_photo_geotagger

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.exifinterface.media.ExifInterface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity : FlutterActivity() {
    private val exifChannelName = "gpx_photo_geotagger/exif"
    private val recorderChannelName = "gpx_photo_geotagger/track_recorder"
    private val recorderEventsName = "gpx_photo_geotagger/track_recorder_events"
    private val permissionRequestCode = 3107
    private val photoPickerRequestCode = 3109
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingPhotoPickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, exifChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readMetadata" -> handleReadMetadata(call, result)
                    "writeGpsMetadata" -> handleWriteGpsMetadata(call, result)
                    "pickWritablePhotos" -> handlePickWritablePhotos(result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, recorderChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermissions" -> requestLocationPermissions(result)
                    "getStatus" -> result.success(TrackRecordingService.payload(this))
                    "getRecordedPoints" -> getRecordedPoints(call, result)
                    "startRecording" -> startRecording(call, result)
                    "pauseRecording" -> dispatchRecorderAction(TrackRecordingService.actionPause, null, result)
                    "resumeRecording" -> dispatchRecorderAction(TrackRecordingService.actionResume, null, result)
                    "stopRecording" -> stopRecording(result)
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, recorderEventsName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    TrackRecorderChannels.attachSink(events)
                    events?.success(TrackRecordingService.payload(this@MainActivity))
                }

                override fun onCancel(arguments: Any?) {
                    TrackRecorderChannels.attachSink(null)
                }
            })
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequestCode) {
            return
        }

        val result = pendingPermissionResult ?: return
        pendingPermissionResult = null
        result.success(TrackRecordingService.payload(this))
        TrackRecorderChannels.emit(TrackRecordingService.payload(this))
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != photoPickerRequestCode) {
            return
        }

        val result = pendingPhotoPickerResult ?: return
        pendingPhotoPickerResult = null

        if (resultCode != RESULT_OK) {
            result.success(emptyList<Map<String, String>>())
            return
        }

        val uris = buildList {
            data?.data?.let(::add)
            val clipData = data?.clipData
            if (clipData != null) {
                for (index in 0 until clipData.itemCount) {
                    clipData.getItemAt(index)?.uri?.let(::add)
                }
            }
        }.distinctBy { it.toString() }

        val payload = uris.map { uri ->
            takePersistablePermission(uri)
            mapOf(
                "source" to uri.toString(),
                "name" to resolveDisplayName(uri, uri.toString()),
            )
        }
        result.success(payload)
    }

    private fun handlePickWritablePhotos(result: MethodChannel.Result) {
        if (pendingPhotoPickerResult != null) {
            result.error("picker_busy", "已有正在进行的照片选择", null)
            return
        }

        pendingPhotoPickerResult = result
        val intent = Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI).apply {
            type = "image/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/jpeg", "image/jpg"))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }

        runCatching {
            startActivityForResult(intent, photoPickerRequestCode)
        }.onFailure { error ->
            pendingPhotoPickerResult = null
            result.error("picker_failed", error.message, null)
        }
    }

    private fun requestLocationPermissions(result: MethodChannel.Result) {
        val permissions = mutableListOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            permissions += Manifest.permission.ACCESS_BACKGROUND_LOCATION
        }

        val missing = permissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            result.success(TrackRecordingService.payload(this))
            return
        }

        pendingPermissionResult = result
        ActivityCompat.requestPermissions(this, missing.toTypedArray(), permissionRequestCode)
    }

    private fun startRecording(call: MethodCall, result: MethodChannel.Result) {
        val intervalMillis = call.argument<Int>("intervalMillis")?.toLong() ?: 5000L
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            result.error("missing_permission", "Location permission is required", null)
            return
        }
        dispatchRecorderAction(TrackRecordingService.actionStart, intervalMillis, result)
    }

    private fun stopRecording(result: MethodChannel.Result) {
        val stoppedPayload = mapOf(
            "sessionId" to TrackRecordingService.sessionId,
            "startedAtMillis" to TrackRecordingService.startedAtMillis,
            "endedAtMillis" to System.currentTimeMillis(),
            "elapsedSeconds" to TrackRecordingService.currentElapsedSeconds(),
            "pointCount" to TrackRecordingService.pointCount,
            "points" to TrackRecordingService.readRecordedPoints(this, TrackRecordingService.sessionId),
        )
        dispatchRecorderAction(TrackRecordingService.actionStop, null, result)
        result.success(stoppedPayload)
    }

    private fun getRecordedPoints(call: MethodCall, result: MethodChannel.Result) {
        val sessionId = call.argument<String>("sessionId") ?: TrackRecordingService.sessionId
        result.success(TrackRecordingService.readRecordedPoints(this, sessionId))
    }

    private fun dispatchRecorderAction(action: String, intervalMillis: Long?, result: MethodChannel.Result) {
        val intent = Intent(this, TrackRecordingService::class.java).apply {
            this.action = action
            if (intervalMillis != null) {
                putExtra("intervalMillis", intervalMillis)
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && action == TrackRecordingService.actionStart) {
            ContextCompat.startForegroundService(this, intent)
        } else {
            startService(intent)
        }
        TrackRecorderChannels.emit(TrackRecordingService.payload(this))
        if (action != TrackRecordingService.actionStop) {
            result.success(TrackRecordingService.payload(this))
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
        val exportFolderName = call.argument<String>("exportFolderName") ?: "GPS Photo Geotagger"
        val exportFileSuffix = call.argument<String>("exportFileSuffix") ?: "_gps_copy"
        val writeToOriginal = call.argument<Boolean>("writeToOriginal") ?: false

        if (source.isNullOrBlank() || latitude == null || longitude == null) {
            result.error("invalid_args", "Missing source or coordinates", null)
            return
        }

        performWriteGpsMetadata(
            source = source,
            latitude = latitude,
            longitude = longitude,
            altitude = altitude,
            gpsDateStamp = gpsDateStamp,
            gpsTimeStamp = gpsTimeStamp,
            exportFolderName = exportFolderName,
            exportFileSuffix = exportFileSuffix,
            writeToOriginal = writeToOriginal,
            result = result,
        )
    }

    private fun performWriteGpsMetadata(
        source: String,
        latitude: Double,
        longitude: Double,
        altitude: Double?,
        gpsDateStamp: String?,
        gpsTimeStamp: String?,
        exportFolderName: String,
        exportFileSuffix: String,
        writeToOriginal: Boolean,
        result: MethodChannel.Result,
    ) {
        runCatching {
            writeWithFallback(
                source = source,
                latitude = latitude,
                longitude = longitude,
                altitude = altitude,
                gpsDateStamp = gpsDateStamp,
                gpsTimeStamp = gpsTimeStamp,
                exportFolderName = exportFolderName,
                exportFileSuffix = exportFileSuffix,
                writeToOriginal = writeToOriginal,
            )
        }.onSuccess {
            result.success(
                mapOf(
                    "target" to it.first,
                    "wroteToOriginal" to it.second,
                )
            )
        }.onFailure { error ->
            result.error("write_failed", error.message, null)
        }
    }

    private fun writeWithFallback(
        source: String,
        latitude: Double,
        longitude: Double,
        altitude: Double?,
        gpsDateStamp: String?,
        gpsTimeStamp: String?,
        exportFolderName: String,
        exportFileSuffix: String,
        writeToOriginal: Boolean,
    ): Pair<String, Boolean> {
        fun writeTo(targetSource: String) {
            withExifInterface(targetSource, writable = true) { exif ->
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
        }

        if (writeToOriginal) {
            val originalResult = runCatching {
                writeTo(source)
                source to true
            }
            if (originalResult.isSuccess) {
                return originalResult.getOrThrow()
            }
        }

        val exportedSource = exportPhotoCopy(source, exportFolderName, exportFileSuffix).toString()
        writeTo(exportedSource)
        return exportedSource to false
    }

    private fun exportPhotoCopy(source: String, exportFolderName: String, exportFileSuffix: String): Uri {
        val sourceUri = if (source.startsWith("content://")) Uri.parse(source) else null
        val displayName = resolveDisplayName(sourceUri, source)
        val targetName = buildExportName(displayName, exportFileSuffix)
        val safeFolderName = sanitizeRelativeFolderPath(exportFolderName)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, targetName)
                put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/$safeFolderName")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }

            val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IOException("无法创建导出图片")

            try {
                copySourceToUri(source, uri)
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
                return uri
            } catch (error: Throwable) {
                contentResolver.delete(uri, null, null)
                throw error
            }
        }

        val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
        val exportDir = File(picturesDir, safeFolderName)
        if (!exportDir.exists()) {
            exportDir.mkdirs()
        }
        val file = File(exportDir, targetName)
        copySourceToFile(source, file)
        return Uri.fromFile(file)
    }

    private fun copySourceToUri(source: String, targetUri: Uri) {
        openSourceInputStream(source).use { input ->
            contentResolver.openOutputStream(targetUri, "w")?.use { output ->
                input.copyTo(output)
            } ?: throw IOException("无法打开导出文件输出流")
        }
    }

    private fun copySourceToFile(source: String, file: File) {
        openSourceInputStream(source).use { input ->
            file.outputStream().use { output ->
                input.copyTo(output)
            }
        }
    }

    private fun openSourceInputStream(source: String) = if (source.startsWith("content://")) {
        contentResolver.openInputStream(Uri.parse(source))
            ?: throw IOException("无法读取源图片")
    } else {
        val path = if (source.startsWith("file://")) Uri.parse(source).path else source
        if (path.isNullOrBlank()) {
            throw IOException("Invalid file path")
        }
        File(path).inputStream()
    }

    private fun resolveDisplayName(sourceUri: Uri?, source: String): String {
        if (sourceUri != null) {
            contentResolver.query(
                sourceUri,
                arrayOf(MediaStore.MediaColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val index = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                    if (index >= 0) {
                        cursor.getString(index)?.takeIf { it.isNotBlank() }?.let { return it }
                    }
                }
            }
            sourceUri.lastPathSegment?.substringAfterLast('/')?.takeIf { it.isNotBlank() }?.let { return it }
        }

        return source.substringAfterLast('/').ifBlank { "photo.jpg" }
    }

    private fun buildExportName(originalName: String, exportFileSuffix: String): String {
        val safeSuffix = sanitizeFileSuffix(exportFileSuffix)
        val dotIndex = originalName.lastIndexOf('.')
        if (dotIndex <= 0) {
            return "${originalName}${safeSuffix}.jpg"
        }
        val name = originalName.substring(0, dotIndex)
        val ext = originalName.substring(dotIndex)
        return "${name}${safeSuffix}$ext"
    }

    private fun sanitizeRelativeFolderPath(value: String): String {
        val segments = value
            .replace('\\', '/')
            .split('/')
            .map { it.trim().replace(Regex("[:*?\"<>|]"), "_") }
            .filter { it.isNotBlank() }

        return if (segments.isEmpty()) {
            "GPS Photo Geotagger"
        } else {
            segments.joinToString("/")
        }
    }

    private fun sanitizeFileSuffix(value: String): String {
        val sanitized = value.trim().replace(Regex("[\\\\/:*?\"<>|\\s]+"), "_")
        if (sanitized.isBlank()) {
            return "_gps_copy"
        }
        return if (sanitized.startsWith("_")) sanitized else "_$sanitized"
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
