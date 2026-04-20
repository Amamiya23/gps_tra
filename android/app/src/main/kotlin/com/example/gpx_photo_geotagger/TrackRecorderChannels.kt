package com.example.gpx_photo_geotagger

import io.flutter.plugin.common.EventChannel

object TrackRecorderChannels {
    private var eventSink: EventChannel.EventSink? = null

    fun attachSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun emit(payload: Map<String, Any?>) {
        eventSink?.success(payload)
    }
}
