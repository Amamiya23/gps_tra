package com.example.gpx_photo_geotagger

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.max

class TrackRecordingService : Service() {
    companion object {
        const val actionStart = "com.example.gpx_photo_geotagger.action.START"
        const val actionPause = "com.example.gpx_photo_geotagger.action.PAUSE"
        const val actionResume = "com.example.gpx_photo_geotagger.action.RESUME"
        const val actionStop = "com.example.gpx_photo_geotagger.action.STOP"

        const val notificationChannelId = "track_recording"
        const val notificationId = 1001

        var state: String = "idle"
        var sessionId: String? = null
        var startedAtMillis: Long? = null
        var elapsedSeconds: Long = 0
        var lastResumedAtMillis: Long? = null
        var pointCount: Int = 0
        var lastLatitude: Double? = null
        var lastLongitude: Double? = null
        var lastAltitude: Double? = null
        var lastAccuracy: Float? = null
        var lastSpeed: Float? = null
        var lastTimestampMillis: Long? = null
        var stoppedSession: Map<String, Any?>? = null

        fun currentElapsedSeconds(): Long {
            val resumedAt = lastResumedAtMillis ?: return elapsedSeconds
            return elapsedSeconds + ((System.currentTimeMillis() - resumedAt).coerceAtLeast(0) / 1000)
        }

        fun payload(context: Context): Map<String, Any?> {
            val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val locationEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
            val fineGranted = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
            val backgroundGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.ACCESS_BACKGROUND_LOCATION,
                ) == PackageManager.PERMISSION_GRANTED
            } else {
                true
            }

            return mapOf(
                "state" to state,
                "sessionId" to sessionId,
                "startedAtMillis" to startedAtMillis,
                "elapsedSeconds" to currentElapsedSeconds(),
                "pointCount" to pointCount,
                "lastLatitude" to lastLatitude,
                "lastLongitude" to lastLongitude,
                "lastAltitude" to lastAltitude,
                "lastAccuracy" to lastAccuracy?.toDouble(),
                "lastSpeed" to lastSpeed?.toDouble(),
                "lastTimestampMillis" to lastTimestampMillis,
                "locationPermissionGranted" to fineGranted,
                "backgroundPermissionGranted" to backgroundGranted,
                "locationEnabled" to locationEnabled,
            )
        }

        fun readRecordedPoints(context: Context, sessionId: String?): List<Map<String, Any?>> {
            val currentSessionId = sessionId ?: return emptyList()
            val file = sessionFile(context, currentSessionId)
            if (!file.exists()) {
                return emptyList()
            }

            return file.useLines { lines ->
                lines
                    .map { it.trim() }
                    .filter { it.isNotEmpty() }
                    .map { line ->
                        val json = JSONObject(line)
                        mapOf(
                            "sessionId" to json.getString("sessionId"),
                            "latitude" to json.getDouble("latitude"),
                            "longitude" to json.getDouble("longitude"),
                            "timestamp" to json.getString("timestamp"),
                            "altitude" to json.optDoubleOrNull("altitude"),
                            "accuracy" to json.optDoubleOrNull("accuracy"),
                            "speed" to json.optDoubleOrNull("speed"),
                        )
                    }
                    .toList()
            }
        }

        private fun sessionFile(context: Context, sessionId: String): File {
            val directory = File(context.filesDir, "track_recording_points")
            return File(directory, "$sessionId.jsonl")
        }

        private fun JSONObject.optDoubleOrNull(key: String): Double? {
            return if (has(key) && !isNull(key)) getDouble(key) else null
        }
    }

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var notificationManager: NotificationManager
    private val timestampFormatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }
    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            if (state != "recording") {
                return
            }
            val locations = result.locations
            if (locations.isEmpty()) {
                val location = result.lastLocation ?: return
                recordLocation(location)
                return
            }
            locations.forEach(::recordLocation)
        }
    }

    private fun recordLocation(location: android.location.Location) {
        if (lastTimestampMillis == location.time &&
            lastLatitude == location.latitude &&
            lastLongitude == location.longitude
        ) {
            return
        }

        pointCount += 1
        lastLatitude = location.latitude
        lastLongitude = location.longitude
        lastAltitude = if (location.hasAltitude()) location.altitude else null
        lastAccuracy = location.accuracy
        lastSpeed = if (location.hasSpeed()) location.speed else null
        lastTimestampMillis = location.time
        appendPointToDisk(location)
        TrackRecorderChannels.emit(payload(this@TrackRecordingService))
        notificationManager.notify(notificationId, buildNotification())
    }

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            actionStart -> {
                val interval = intent.getLongExtra("intervalMillis", 5000L)
                startRecording(interval)
            }
            actionPause -> pauseRecording()
            actionResume -> resumeRecording()
            actionStop -> stopRecording()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private var currentIntervalMillis = 5000L

    private fun startRecording(intervalMillis: Long) {
        currentIntervalMillis = intervalMillis
        state = "recording"
        startedAtMillis = System.currentTimeMillis()
        sessionId = startedAtMillis?.toString()
        lastResumedAtMillis = startedAtMillis
        elapsedSeconds = 0
        pointCount = 0
        lastLatitude = null
        lastLongitude = null
        lastAltitude = null
        lastAccuracy = null
        lastSpeed = null
        lastTimestampMillis = null
        stoppedSession = null
        resetSessionFile()
        startForeground(notificationId, buildNotification())
        requestLocationUpdates()
        TrackRecorderChannels.emit(payload(this))
    }

    private fun pauseRecording() {
        if (state != "recording") return
        accumulateElapsed()
        state = "paused"
        fusedLocationClient.removeLocationUpdates(locationCallback)
        notificationManager.notify(notificationId, buildNotification())
        TrackRecorderChannels.emit(payload(this))
    }

    private fun resumeRecording() {
        if (state != "paused") return
        state = "recording"
        lastResumedAtMillis = System.currentTimeMillis()
        requestLocationUpdates()
        notificationManager.notify(notificationId, buildNotification())
        TrackRecorderChannels.emit(payload(this))
    }

    private fun stopRecording() {
        if (state == "recording") {
            accumulateElapsed()
        }
        fusedLocationClient.removeLocationUpdates(locationCallback)
        stoppedSession = mapOf(
            "sessionId" to sessionId,
            "startedAtMillis" to startedAtMillis,
            "endedAtMillis" to System.currentTimeMillis(),
            "elapsedSeconds" to currentElapsedSeconds(),
            "pointCount" to pointCount,
            "points" to readRecordedPoints(this, sessionId),
        )
        state = "idle"
        sessionId = null
        startedAtMillis = null
        lastResumedAtMillis = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        TrackRecorderChannels.emit(payload(this))
    }

    private fun accumulateElapsed() {
        val resumedAt = lastResumedAtMillis ?: return
        val deltaMillis = (System.currentTimeMillis() - resumedAt).coerceAtLeast(0)
        elapsedSeconds += deltaMillis / 1000
        lastResumedAtMillis = null
    }

    private fun requestLocationUpdates() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            return
        }

        val request = LocationRequest.Builder(currentIntervalMillis)
            .setMinUpdateIntervalMillis(max(1000L, currentIntervalMillis / 2))
            .setMaxUpdateDelayMillis(currentIntervalMillis)
            .setWaitForAccurateLocation(false)
            .setPriority(LocationRequest.PRIORITY_HIGH_ACCURACY)
            .build()

        fusedLocationClient.requestLocationUpdates(
            request,
            locationCallback,
            Looper.getMainLooper(),
        )
    }

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val contentText = when (state) {
            "recording" -> "正在记录轨迹，已记录 ${elapsedSeconds} 秒，$pointCount 个点"
            "paused" -> "轨迹记录已暂停"
            else -> "轨迹记录待启动"
        }

        return NotificationCompat.Builder(this, notificationChannelId)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("轨迹记录")
            .setContentText(contentText)
            .setContentIntent(pendingIntent)
            .setOngoing(state != "idle")
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val channel = NotificationChannel(
            notificationChannelId,
            "轨迹记录",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "后台轨迹记录服务"
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun resetSessionFile() {
        val currentSessionId = sessionId ?: return
        val directory = File(filesDir, "track_recording_points")
        directory.mkdirs()
        sessionFile(this, currentSessionId).writeText("")
    }

    private fun appendPointToDisk(location: android.location.Location) {
        val currentSessionId = sessionId ?: return
        val directory = File(filesDir, "track_recording_points")
        directory.mkdirs()
        val point = JSONObject().apply {
            put("sessionId", currentSessionId)
            put("latitude", location.latitude)
            put("longitude", location.longitude)
            put("timestamp", timestampFormatter.format(Date(location.time)))
            if (location.hasAltitude()) {
                put("altitude", location.altitude)
            }
            put("accuracy", location.accuracy.toDouble())
            if (location.hasSpeed()) {
                put("speed", location.speed.toDouble())
            }
        }
        sessionFile(this, currentSessionId).appendText(point.toString() + "\n")
    }
}
