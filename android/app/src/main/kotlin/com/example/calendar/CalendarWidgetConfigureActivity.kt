package com.example.calendar

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.SeekBar
import android.widget.TextView
import android.widget.Toast

class CalendarWidgetConfigureActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        setContentView(R.layout.calendar_widget_configure)
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
}
