package com.example.calendar

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.content.res.Configuration
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView
import android.view.ViewGroup
import android.widget.Toast

class CalendarWidgetConfigureActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        val settings = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val darkTheme = when (settings.getString("flutter.settings.theme_mode", "system")) {
            "dark" -> true
            "light" -> false
            else -> resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK ==
                Configuration.UI_MODE_NIGHT_YES
        }
        setTheme(
            if (darkTheme) R.style.WidgetConfigureDarkTheme else R.style.WidgetConfigureTheme,
        )
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        setContentView(R.layout.calendar_widget_configure)
        applyAppTheme(
            themeType = settings.getString("flutter.settings.theme_type", "systemDynamic")
                ?: "systemDynamic",
            darkTheme = darkTheme,
        )
        window?.let {
            val density = resources.displayMetrics.density
            val width = (resources.displayMetrics.widthPixels * 0.9f)
                .toInt()
                .coerceAtMost((420 * density).toInt())
            it.setLayout(width, ViewGroup.LayoutParams.WRAP_CONTENT)
        }
        appWidgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val preferences = getSharedPreferences(
            "calendar_widget_preferences",
            MODE_PRIVATE,
        )
        val valueLabel = findViewById<TextView>(R.id.widget_transparency_value)
        val seekBar = findViewById<SeekBar>(R.id.widget_transparency_seekbar)
        seekBar.progress = preferences.getInt("transparency_$appWidgetId", 20)
            .coerceIn(0, seekBar.max)
        updateLabel(valueLabel, seekBar.progress)
        seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar, progress: Int, fromUser: Boolean) {
                updateLabel(valueLabel, progress)
            }

            override fun onStartTrackingTouch(seekBar: SeekBar) = Unit

            override fun onStopTrackingTouch(seekBar: SeekBar) = Unit
        })
        findViewById<Button>(R.id.widget_cancel).setOnClickListener { finish() }
        findViewById<Button>(R.id.widget_save).setOnClickListener {
            if (!preferences.edit().putInt("transparency_$appWidgetId", seekBar.progress).commit()) {
                Toast.makeText(this, R.string.calendar_widget_save_error, Toast.LENGTH_LONG).show()
                return@setOnClickListener
            }
            CalendarWidgetProvider.updateWidget(
                this,
                AppWidgetManager.getInstance(this),
                appWidgetId,
            )
            val result = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            setResult(RESULT_OK, result)
            finish()
        }
    }

    private fun updateLabel(label: TextView, progress: Int) {
        label.text = getString(R.string.calendar_widget_transparency_value, progress)
    }

    private fun applyAppTheme(themeType: String, darkTheme: Boolean) {
        val primary = when (themeType) {
            "emeraldForest" -> Color.rgb(5, 150, 105)
            "sunsetAmber" -> Color.rgb(217, 119, 6)
            "deepPurple" -> Color.rgb(124, 58, 237)
            "roseCrimson" -> Color.rgb(225, 29, 72)
            "systemDynamic" -> systemAccentColor(darkTheme)
            else -> Color.rgb(37, 99, 235)
        }
        val surface = if (darkTheme) Color.rgb(17, 24, 39) else Color.rgb(248, 250, 252)
        val onSurface = if (darkTheme) Color.WHITE else Color.rgb(31, 41, 55)
        val secondary = if (darkTheme) Color.rgb(203, 213, 225) else Color.rgb(100, 116, 139)

        findViewById<LinearLayout>(R.id.widget_settings_root).background =
            GradientDrawable().apply {
                setColor(surface)
                cornerRadius = 20 * resources.displayMetrics.density
                setStroke(
                    (resources.displayMetrics.density).toInt().coerceAtLeast(1),
                    if (darkTheme) Color.rgb(55, 65, 81) else Color.rgb(226, 232, 240),
                )
            }
        findViewById<TextView>(R.id.widget_settings_title).setTextColor(onSurface)
        findViewById<TextView>(R.id.widget_settings_description).setTextColor(secondary)
        findViewById<TextView>(R.id.widget_transparency_label).setTextColor(onSurface)
        findViewById<TextView>(R.id.widget_transparency_value).setTextColor(secondary)
        findViewById<ImageView>(R.id.widget_settings_icon).apply {
            imageTintList = ColorStateList.valueOf(primary)
            background = GradientDrawable().apply {
                setColor((primary and 0x00FFFFFF) or 0x22000000)
                cornerRadius = 20 * resources.displayMetrics.density
            }
        }
        findViewById<SeekBar>(R.id.widget_transparency_seekbar).apply {
            progressTintList = ColorStateList.valueOf(primary)
            thumbTintList = ColorStateList.valueOf(primary)
        }
        findViewById<Button>(R.id.widget_cancel).setTextColor(primary)
        findViewById<Button>(R.id.widget_save).apply {
            backgroundTintList = ColorStateList.valueOf(primary)
            setTextColor(if (darkTheme) Color.BLACK else Color.WHITE)
        }
    }

    private fun systemAccentColor(darkTheme: Boolean): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val tone = if (darkTheme) "system_accent1_200" else "system_accent1_600"
            val colorId = resources.getIdentifier(tone, "color", "android")
            if (colorId != 0) return getColor(colorId)
        }
        return Color.rgb(37, 99, 235)
    }
}
