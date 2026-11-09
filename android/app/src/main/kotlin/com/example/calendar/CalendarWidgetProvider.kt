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
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.util.Calendar
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
        private const val EVENT_DATE_WINDOW_DAYS = 7
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
            views.setViewVisibility(R.id.widget_more_events, View.GONE)

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
                            now,
                        )
                        val secondEvent = calendarData.events.getOrNull(1)
                        if (showsSecondEvent && secondEvent != null) {
                            setEvent(
                                context,
                                views,
                                secondEvent,
                                R.id.widget_event_two_time,
                                R.id.widget_event_two_title,
                                now,
                            )
                            views.setViewVisibility(R.id.widget_event_two, View.VISIBLE)
                        } else {
                            views.setViewVisibility(R.id.widget_event_two, View.GONE)
                        }
                        val visibleEvents = if (showsSecondEvent && secondEvent != null) {
                            listOf(calendarData.events[0], secondEvent)
                        } else {
                            listOf(calendarData.events[0])
                        }
                        val visibleOnFirstDay = visibleEvents.count {
                            isSameLocalDay(it.begin, calendarData.events[0].begin)
                        }
                        val additionalEvents =
                            calendarData.firstDayEventCount - visibleOnFirstDay
                        if (additionalEvents > 0) {
                            views.setTextViewText(
                                R.id.widget_more_events,
                                context.getString(
                                    R.string.calendar_widget_more_events,
                                    additionalEvents,
                                ),
                            )
                            views.setViewVisibility(R.id.widget_more_events, View.VISIBLE)
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
            now: Long,
        ) {
            val time = if (event.allDay) {
                context.getString(R.string.calendar_widget_all_day)
            } else {
                DateFormat.getTimeFormat(context).format(Date(event.begin))
            }
            val date = Calendar.getInstance().apply {
                timeInMillis = now
                add(Calendar.DAY_OF_YEAR, EVENT_DATE_WINDOW_DAYS)
            }.timeInMillis
            val summary = if (event.begin >= now && event.begin < date) {
                "${DateFormat.getDateFormat(context).format(Date(event.begin))} · $time"
            } else {
                time
            }
            views.setTextViewText(timeViewId, summary)
            views.setTextViewText(titleViewId, event.title)
        }

        private fun readUpcomingEvents(context: Context, now: Long): CalendarData {
            val end = Calendar.getInstance().apply {
                timeInMillis = now
                add(Calendar.DAY_OF_YEAR, EVENT_DATE_WINDOW_DAYS)
            }.timeInMillis
            val events = readLocalEvents(context, now, end).toMutableList()
            if (
                ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALENDAR) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                return calendarData(events, permissionDenied = events.isEmpty())
            }

            val preferences = context
                .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val selectedCalendars = readSelectedCalendars(preferences.all)
            if (selectedCalendars is CalendarSelection.Invalid) {
                Log.e("CalendarWidget", "Unable to read selected calendar IDs.")
                return calendarData(events, failedToLoad = events.isEmpty())
            }
            val start = now - TimeUnit.DAYS.toMillis(1)
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
                return calendarData(events, permissionDenied = events.isEmpty())
            }
            if (cursor == null) {
                Log.e("CalendarWidget", "Calendar provider returned no event cursor.")
                return calendarData(events, failedToLoad = events.isEmpty())
            }
            cursor.use {
                val titleColumn = it.getColumnIndexOrThrow(CalendarContract.Instances.TITLE)
                val beginColumn = it.getColumnIndexOrThrow(CalendarContract.Instances.BEGIN)
                val allDayColumn = it.getColumnIndexOrThrow(CalendarContract.Instances.ALL_DAY)
                val calendarColumn = it.getColumnIndexOrThrow(CalendarContract.Instances.CALENDAR_ID)
                while (it.moveToNext()) {
                    val calendarId = it.getString(calendarColumn)
                    if (selectedIds != null && calendarId !in selectedIds) continue
                    val begin = it.getLong(beginColumn)
                    if (begin >= end) continue
                    events += WidgetEvent(
                        title = it.getString(titleColumn)?.takeIf(String::isNotBlank)
                            ?: context.getString(R.string.calendar_widget_untitled),
                        begin = begin,
                        allDay = it.getInt(allDayColumn) != 0,
                    )
                }
            }
            return calendarData(events)
        }

        private fun calendarData(
            events: List<WidgetEvent>,
            permissionDenied: Boolean = false,
            failedToLoad: Boolean = false,
        ): CalendarData {
            val orderedEvents = events.sortedBy(WidgetEvent::begin)
            val firstDayEventCount = orderedEvents.firstOrNull()?.let { firstEvent ->
                orderedEvents.count { isSameLocalDay(it.begin, firstEvent.begin) }
            } ?: 0
            return CalendarData(
                events = orderedEvents.take(2),
                firstDayEventCount = firstDayEventCount,
                permissionDenied = permissionDenied,
                failedToLoad = failedToLoad,
            )
        }

        private fun readLocalEvents(context: Context, now: Long, end: Long): List<WidgetEvent> {
            val preferences = context
                .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val encoded = preferences.getString("flutter.settings.local_events", null)
                ?: return emptyList()
            val values = try {
                JSONArray(encoded)
            } catch (error: JSONException) {
                Log.e("CalendarWidget", "Local calendar events are not valid JSON.", error)
                return emptyList()
            }

            return buildList {
                for (index in 0 until values.length()) {
                    val event = values.optJSONObject(index) ?: continue
                    addLocalEventOccurrences(context, event, now, end)?.let(::addAll)
                }
            }
        }

        private fun addLocalEventOccurrences(
            context: Context,
            event: JSONObject,
            now: Long,
            end: Long,
        ): List<WidgetEvent>? {
            val start = parseDate(event.optString("startTime"))
            val eventEnd = parseDate(event.optString("endTime"))
            if (start == null || eventEnd == null || eventEnd < start) {
                Log.e("CalendarWidget", "Skipping a local event with invalid dates.")
                return null
            }
            val duration = eventEnd - start
            val frequency = event.optString("recurrenceFrequency").takeUnless {
                it.isBlank() || it == "null"
            }
            val recurrenceEnd = parseDate(event.optString("recurrenceEndDate"))
            val excludedDates = event.optJSONArray("excludedOccurrenceDates")
                ?.let { dates ->
                    buildSet {
                        for (index in 0 until dates.length()) {
                            dates.optString(index).takeIf(String::isNotBlank)?.let(::add)
                        }
                    }
                } ?: emptySet()
            val lowerBound = maxOf(start, now - duration)
            var occurrenceIndex = firstOccurrenceIndex(start, frequency, lowerBound)
            val occurrences = mutableListOf<WidgetEvent>()

            while (true) {
                val occurrenceStart = occurrenceStart(start, frequency, occurrenceIndex)
                    ?: break
                if (occurrenceStart >= end) break
                if (recurrenceEnd != null && isAfterLocalDay(occurrenceStart, recurrenceEnd)) {
                    break
                }
                val occurrenceEnd = occurrenceStart + duration
                val dateKey = localDateKey(occurrenceStart)
                if (
                    occurrenceEnd > now &&
                    dateKey !in excludedDates
                ) {
                    occurrences += WidgetEvent(
                        title = event.optString("title").takeIf(String::isNotBlank)
                            ?: context.getString(R.string.calendar_widget_untitled),
                        begin = occurrenceStart,
                        allDay = event.optBoolean("isAllDay", false),
                    )
                }
                if (frequency == null) break
                occurrenceIndex++
            }
            return occurrences
        }

        private fun firstOccurrenceIndex(start: Long, frequency: String?, lowerBound: Long): Int {
            if (frequency == null || lowerBound <= start) return 0
            val startDate = Calendar.getInstance().apply { timeInMillis = start }
            val lowerDate = Calendar.getInstance().apply { timeInMillis = lowerBound }
            return when (frequency) {
                "weekly", "everyTwoWeeks", "everyThreeWeeks" -> {
                    val intervalWeeks = when (frequency) {
                        "everyTwoWeeks" -> 2
                        "everyThreeWeeks" -> 3
                        else -> 1
                    }
                    val startDay = localDate(startDate).toEpochDay()
                    val lowerDay = localDate(lowerDate).toEpochDay()
                    ((lowerDay - startDay) / (7L * intervalWeeks) - 1)
                        .coerceAtLeast(0)
                        .coerceAtMost(Int.MAX_VALUE.toLong())
                        .toInt()
                }
                "monthly" -> {
                    val months = (lowerDate.get(Calendar.YEAR) - startDate.get(Calendar.YEAR)) * 12 +
                        lowerDate.get(Calendar.MONTH) - startDate.get(Calendar.MONTH)
                    (months - 1).coerceAtLeast(0)
                }
                else -> 0
            }
        }

        private fun occurrenceStart(start: Long, frequency: String?, index: Int): Long? {
            if (index == 0) return start
            val calendar = Calendar.getInstance().apply { timeInMillis = start }
            when (frequency) {
                "weekly", "everyTwoWeeks", "everyThreeWeeks" -> {
                    val intervalWeeks = when (frequency) {
                        "everyTwoWeeks" -> 2
                        "everyThreeWeeks" -> 3
                        else -> 1
                    }
                    calendar.add(Calendar.DAY_OF_YEAR, 7 * intervalWeeks * index)
                }
                "monthly" -> {
                    val day = calendar.get(Calendar.DAY_OF_MONTH)
                    calendar.set(Calendar.DAY_OF_MONTH, 1)
                    calendar.add(Calendar.MONTH, index)
                    val lastDay = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)
                    calendar.set(Calendar.DAY_OF_MONTH, minOf(day, lastDay))
                }
                else -> return null
            }
            return calendar.timeInMillis
        }

        private fun parseDate(value: String): Long? {
            if (value.isBlank() || value == "null") return null
            try {
                return Instant.parse(value).toEpochMilli()
            } catch (_: DateTimeParseException) {
                // Local DateTime strings from Dart have no timezone suffix.
            }
            try {
                return OffsetDateTime.parse(value, DateTimeFormatter.ISO_DATE_TIME)
                    .toInstant()
                    .toEpochMilli()
            } catch (_: DateTimeParseException) {
                // Try interpreting timezone-free values in the device timezone.
            }
            return try {
                LocalDateTime.parse(value, DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                    .atZone(ZoneId.systemDefault())
                    .toInstant()
                    .toEpochMilli()
            } catch (_: DateTimeParseException) {
                null
            }
        }

        private fun localDate(date: Calendar): LocalDate = LocalDate.of(
            date.get(Calendar.YEAR),
            date.get(Calendar.MONTH) + 1,
            date.get(Calendar.DAY_OF_MONTH),
        )

        private fun localDateKey(time: Long): String {
            val date = Calendar.getInstance().apply { timeInMillis = time }
            return String.format(
                Locale.US,
                "%04d-%02d-%02d",
                date.get(Calendar.YEAR),
                date.get(Calendar.MONTH) + 1,
                date.get(Calendar.DAY_OF_MONTH),
            )
        }

        private fun isAfterLocalDay(first: Long, second: Long): Boolean {
            val firstDay = Calendar.getInstance().apply { timeInMillis = first }
            val secondDay = Calendar.getInstance().apply { timeInMillis = second }
            return firstDay.get(Calendar.YEAR) > secondDay.get(Calendar.YEAR) ||
                (firstDay.get(Calendar.YEAR) == secondDay.get(Calendar.YEAR) &&
                    firstDay.get(Calendar.DAY_OF_YEAR) > secondDay.get(Calendar.DAY_OF_YEAR))
        }

        private fun isSameLocalDay(first: Long, second: Long): Boolean {
            val firstDay = Calendar.getInstance().apply { timeInMillis = first }
            val secondDay = Calendar.getInstance().apply { timeInMillis = second }
            return firstDay.get(Calendar.YEAR) == secondDay.get(Calendar.YEAR) &&
                firstDay.get(Calendar.DAY_OF_YEAR) == secondDay.get(Calendar.DAY_OF_YEAR)
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
    val firstDayEventCount: Int = 0,
    val permissionDenied: Boolean = false,
    val failedToLoad: Boolean = false,
)
