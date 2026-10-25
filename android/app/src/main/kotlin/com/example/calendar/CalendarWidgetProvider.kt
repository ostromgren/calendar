package com.example.calendar

import android.Manifest
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.provider.CalendarContract
import android.util.Log
import android.text.format.DateFormat
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONException
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit

class CalendarWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { updateWidget(context, manager, it) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        updateWidget(context, manager, appWidgetId)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        preferences.edit().apply {
            appWidgetIds.forEach { remove("transparency_$it") }
        }.apply()
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_BOOT_COMPLETED,
            -> {
                val manager = AppWidgetManager.getInstance(context)
                val component = ComponentName(context, CalendarWidgetProvider::class.java)
                manager.getAppWidgetIds(component).forEach { updateWidget(context, manager, it) }
            }
        }
    }

    companion object {
        private const val PREFS = "calendar_widget_preferences"
        private const val DEFAULT_TRANSPARENCY = 20
        private const val MAX_TRANSPARENCY = 80
        private const val SHOW_EVENT_WIDTH_DP = 180
        private const val SHOW_SECOND_EVENT_HEIGHT_DP = 150

        fun updateWidget(context: Context, manager: AppWidgetManager, appWidgetId: Int) {
            val options = manager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
            val showsEvents = minWidth >= SHOW_EVENT_WIDTH_DP
            val showsSecondEvent = showsEvents && minHeight >= SHOW_SECOND_EVENT_HEIGHT_DP
            val views = RemoteViews(context.packageName, R.layout.calendar_widget)
            val now = System.currentTimeMillis()
            val locale = Locale.getDefault()
            views.setTextViewText(
                R.id.widget_day,
                SimpleDateFormat("d", locale).format(Date(now)),
            )
            views.setTextViewText(
                R.id.widget_month,
                SimpleDateFormat("MMMM", locale).format(Date(now)),
            )
            val transparency = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getInt("transparency_$appWidgetId", DEFAULT_TRANSPARENCY)
                .coerceIn(0, MAX_TRANSPARENCY)
            val backgroundAlpha = (100 - transparency) / 100f
            views.setFloat(
                R.id.widget_background,
                "setAlpha",
                backgroundAlpha,
            )
            views.setViewVisibility(
                R.id.widget_divider,
                if (showsEvents) View.VISIBLE else View.GONE,
            )
            views.setViewVisibility(
                R.id.widget_events,
                if (showsEvents) View.VISIBLE else View.GONE,
            )

            if (showsEvents) {
                val calendarData = readUpcomingEvents(context, now)
                when {
                    calendarData.permissionDenied -> {
                        views.setTextViewText(
                            R.id.widget_event_one_title,
                            context.getString(R.string.calendar_widget_permission),
                        )
                        views.setTextViewText(R.id.widget_event_one_time, "")
                        views.setViewVisibility(R.id.widget_event_two, View.GONE)
                    }
                    calendarData.failedToLoad -> {
                        views.setTextViewText(
                            R.id.widget_event_one_title,
                            context.getString(R.string.calendar_widget_load_error),
                        )
                        views.setTextViewText(R.id.widget_event_one_time, "")
                        views.setViewVisibility(R.id.widget_event_two, View.GONE)
                    }
                    calendarData.events.isEmpty() -> {
                        views.setTextViewText(
                            R.id.widget_event_one_title,
                            context.getString(R.string.calendar_widget_no_events),
                        )
                        views.setTextViewText(R.id.widget_event_one_time, "")
                        views.setViewVisibility(R.id.widget_event_two, View.GONE)
                    }
                    else -> {
                        setEvent(
                            context,
                            views,
                            calendarData.events[0],
                            R.id.widget_event_one_time,
                            R.id.widget_event_one_title,
                        )
                        val secondEvent = calendarData.events.getOrNull(1)
                        if (showsSecondEvent && secondEvent != null) {
                            setEvent(
                                context,
                                views,
                                secondEvent,
                                R.id.widget_event_two_time,
                                R.id.widget_event_two_title,
                            )
                            views.setViewVisibility(R.id.widget_event_two, View.VISIBLE)
                        } else {
                            views.setViewVisibility(R.id.widget_event_two, View.GONE)
                        }
                    }
                }
            }

            val openApp = PendingIntent.getActivity(
                context,
                appWidgetId,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_content, openApp)
            manager.updateAppWidget(appWidgetId, views)
        }

        private fun setEvent(
            context: Context,
            views: RemoteViews,
            event: WidgetEvent,
            timeViewId: Int,
            titleViewId: Int,
        ) {
            val time = if (event.allDay) {
                context.getString(R.string.calendar_widget_all_day)
            } else {
                DateFormat.getTimeFormat(context).format(Date(event.begin))
            }
            views.setTextViewText(timeViewId, time)
            views.setTextViewText(titleViewId, event.title)
        }

        private fun readUpcomingEvents(context: Context, now: Long): CalendarData {
            if (
                ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALENDAR) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                return CalendarData(permissionDenied = true)
            }

            val preferences = context
                .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val selectedCalendars = readSelectedCalendars(preferences.all)
            if (selectedCalendars is CalendarSelection.Invalid) {
                Log.e("CalendarWidget", "Unable to read selected calendar IDs.")
                return CalendarData(failedToLoad = true)
            }
            val start = now - TimeUnit.DAYS.toMillis(1)
            val end = now + TimeUnit.DAYS.toMillis(90)
            val instancesUri: Uri = CalendarContract.Instances.CONTENT_URI.buildUpon()
                .appendPath(start.toString())
                .appendPath(end.toString())
                .build()
            val projection = arrayOf(
                CalendarContract.Instances.TITLE,
                CalendarContract.Instances.BEGIN,
                CalendarContract.Instances.ALL_DAY,
                CalendarContract.Instances.CALENDAR_ID,
            )
            val selectedIds = (selectedCalendars as? CalendarSelection.Selected)?.ids
            val events = mutableListOf<WidgetEvent>()
            val cursor: Cursor? = try {
                context.contentResolver.query(
                    instancesUri,
                    projection,
                    "${CalendarContract.Instances.END} > ?",
                    arrayOf(now.toString()),
                    "${CalendarContract.Instances.BEGIN} ASC",
                )
            } catch (error: SecurityException) {
                Log.e("CalendarWidget", "Calendar permission was revoked while loading events.", error)
                return CalendarData(permissionDenied = true)
            }
            if (cursor == null) {
                Log.e("CalendarWidget", "Calendar provider returned no event cursor.")
                return CalendarData(failedToLoad = true)
            }
            cursor.use {
                val titleColumn = it.getColumnIndexOrThrow(CalendarContract.Instances.TITLE)
                val beginColumn = it.getColumnIndexOrThrow(CalendarContract.Instances.BEGIN)
                val allDayColumn = it.getColumnIndexOrThrow(CalendarContract.Instances.ALL_DAY)
                val calendarColumn = it.getColumnIndexOrThrow(CalendarContract.Instances.CALENDAR_ID)
                while (it.moveToNext() && events.size < 2) {
                    val calendarId = it.getString(calendarColumn)
                    if (selectedIds != null && calendarId !in selectedIds) continue
                    events += WidgetEvent(
                        title = it.getString(titleColumn)?.takeIf(String::isNotBlank)
                            ?: context.getString(R.string.calendar_widget_untitled),
                        begin = it.getLong(beginColumn),
                        allDay = it.getInt(allDayColumn) != 0,
                    )
                }
            }
            return CalendarData(events = events)
        }

        private fun readSelectedCalendars(
            preferences: Map<String, *>,
        ): CalendarSelection {
            val key = "flutter.settings.device_calendar_ids"
            val value = preferences[key] ?: return CalendarSelection.All
            if (value is Set<*>) {
                return CalendarSelection.Selected(value.filterIsInstance<String>().toSet())
            }
            if (value !is String || !value.startsWith(JSON_LIST_PREFIX)) {
                return CalendarSelection.Invalid
            }
            return try {
                val json = JSONArray(value.substring(JSON_LIST_PREFIX.length))
                CalendarSelection.Selected(
                    buildSet {
                        for (index in 0 until json.length()) add(json.getString(index))
                    },
                )
            } catch (error: JSONException) {
                Log.e("CalendarWidget", "Selected calendar IDs are not valid JSON.", error)
                CalendarSelection.Invalid
            }
        }

        private const val JSON_LIST_PREFIX =
            "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!"
    }
}

private sealed interface CalendarSelection {
    data object All : CalendarSelection
    data class Selected(val ids: Set<String>) : CalendarSelection
    data object Invalid : CalendarSelection
}

private data class WidgetEvent(
    val title: String,
    val begin: Long,
    val allDay: Boolean,
)

private data class CalendarData(
    val events: List<WidgetEvent> = emptyList(),
    val permissionDenied: Boolean = false,
    val failedToLoad: Boolean = false,
)
