package app.tithi.pro.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.RadioGroup
import app.tithi.pro.R

/**
 * Widget-local theme picker.
 *
 * Shown when the widget is added (android:configure) and on API 31+ via
 * long-press → Reconfigure (android:widgetFeatures="reconfigurable").
 * The choice is stored under [WidgetCountdownData.KEY_THEME] and is owned
 * solely by the widget — app syncs never overwrite it.
 *
 * Memory: plain Activity, no static state; all views are released on finish.
 */
class FestivalCountdownWidgetConfigureActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.widget_theme_config)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        // Cancelled by default so dismissing without saving adds nothing broken.
        setResult(RESULT_CANCELED)

        val prefs = getSharedPreferences(
            WidgetCountdownData.PREFS_NAME,
            Context.MODE_PRIVATE,
        )
        findViewById<RadioGroup>(R.id.widget_theme_group).check(
            when (prefs.getString(WidgetCountdownData.KEY_THEME, "system")) {
                "light" -> R.id.widget_theme_shukla
                "dark" -> R.id.widget_theme_dark
                else -> R.id.widget_theme_auto
            },
        )

        findViewById<Button>(R.id.widget_theme_cancel).setOnClickListener { finish() }
        findViewById<Button>(R.id.widget_theme_save).setOnClickListener {
            // A damaged host can deliver no valid id: binding with
            // INVALID_APPWIDGET_ID confuses the launcher, so report
            // cancellation and don't bind a broken instance.
            if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
                setResult(RESULT_CANCELED)
                finish()
                return@setOnClickListener
            }
            val selected = when (
                findViewById<RadioGroup>(R.id.widget_theme_group).checkedRadioButtonId
            ) {
                R.id.widget_theme_shukla -> "light"
                R.id.widget_theme_dark -> "dark"
                else -> "system"
            }
            prefs.edit().putString(WidgetCountdownData.KEY_THEME, selected).apply()

            // Rebuild every instance in-process so the new theme repaints
            // immediately (no broadcast round-trip for the launcher to drop).
            FestivalCountdownWidgetProvider.refreshAll(this)

            setResult(
                RESULT_OK,
                Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
            )
            finish()
        }
    }
}
