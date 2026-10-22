package com.example.calendar

import android.content.Intent
import android.provider.CalendarContract
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {
    private val channelName = "calendar/native_intents"
    private val pendingRequests = mutableListOf<Map<String, Any>>()
    private var intentChannel: MethodChannel? = null
    private var dartReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        intentChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "takePendingEvents") {
                    dartReady = true
                    result.success(pendingRequests.toList())
                    pendingRequests.clear()
                } else {
                    result.notImplemented()
                }
            }
        }
        handleCalendarIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleCalendarIntent(intent)
    }

    private fun handleCalendarIntent(intent: Intent?) {
        if (intent == null) return

        val request = when (intent.action) {
            Intent.ACTION_INSERT -> {
                val start = intent.getLongExtra(
                    CalendarContract.EXTRA_EVENT_BEGIN_TIME,
                    System.currentTimeMillis()
                )
                val end = intent.getLongExtra(
                    CalendarContract.EXTRA_EVENT_END_TIME,
                    start + 60 * 60 * 1000
                )
                mapOf(
                    "kind" to "event",
                    "title" to (
                        intent.getStringExtra(CalendarContract.Events.TITLE)
                            ?: intent.getStringExtra(Intent.EXTRA_TITLE)
                            ?: ""
                    ),
                    "description" to (intent.getStringExtra(CalendarContract.Events.DESCRIPTION) ?: ""),
                    "startTime" to start,
                    "endTime" to end,
                    "allDay" to intent.getBooleanExtra(CalendarContract.EXTRA_EVENT_ALL_DAY, false)
                )
            }
            Intent.ACTION_VIEW -> {
                val uri = intent.data ?: return
                val contents = try {
                    contentResolver.openInputStream(uri)
                        ?.bufferedReader()
                        ?.use { it.readText() }
                } catch (error: IOException) {
                    dispatchCalendarRequest(
                        mapOf(
                            "kind" to "error",
                            "code" to "calendarFileReadError",
                            "details" to (error.message ?: "")
                        )
                    )
                    return
                } catch (error: SecurityException) {
                    dispatchCalendarRequest(
                        mapOf(
                            "kind" to "error",
                            "code" to "calendarFileReadError",
                            "details" to (error.message ?: "")
                        )
                    )
                    return
                }
                if (contents == null) {
                    dispatchCalendarRequest(
                        mapOf(
                            "kind" to "error",
                            "code" to "calendarFileReadError",
                            "details" to "The selected file could not be opened."
                        )
                    )
                    return
                }
                mapOf("kind" to "ics", "contents" to contents)
            }
            else -> return
        }

        dispatchCalendarRequest(request)
    }

    private fun dispatchCalendarRequest(request: Map<String, Any>) {
        val channel = intentChannel
        if (channel == null || !dartReady) {
            pendingRequests.add(request)
        } else {
            channel.invokeMethod("incomingCalendarRequest", request)
        }
    }
}
