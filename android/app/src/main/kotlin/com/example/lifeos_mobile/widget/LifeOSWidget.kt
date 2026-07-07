package com.example.lifeos_mobile.widget

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalSize
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.background
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.example.lifeos_mobile.MainActivity
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import HomeWidgetGlanceState
import HomeWidgetGlanceStateDefinition
import org.json.JSONArray
import org.json.JSONObject

/** Key the app writes the whole snapshot under (see `WidgetSyncService`). */
private const val SNAPSHOT_KEY = "lifeos_widget_snapshot"
private val HABIT_ID_KEY = ActionParameters.Key<String>("habitId")

/** Reads the app's live theme (AppColors) out of the snapshot instead of a
 * hardcoded guess, so the widget re-skins itself with whatever accent/mode
 * the user picked in Settings. Defaults match AppColors' dark palette +
 * default chartreuse accent for the pre-first-sync cold start. */
private class WidgetTheme(json: JSONObject?) {
    val bg = colorOf(json, "bgColor", 0xFF0A0B0DL)
    val fg = colorOf(json, "textColor", 0xFFECEEF0L)
    val fgMuted = colorOf(json, "mutedTextColor", 0xFFA6ABB3L)
    val accent = colorOf(json, "accentColor", 0xFFC5F23FL)
    val accentInk = colorOf(json, "accentInkColor", 0xFF11160AL)

    private fun colorOf(json: JSONObject?, key: String, default: Long): Color =
        Color(json?.optLong(key, default)?.toInt() ?: default.toInt())
}

private fun solid(color: Color) = ColorProvider(color)

class LifeOSWidget : GlanceAppWidget() {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent { Content(context, currentState()) }
    }

    @Composable
    private fun Content(context: Context, state: HomeWidgetGlanceState) {
        val raw = state.preferences.getString(SNAPSHOT_KEY, null)
        val snapshot = raw?.let { runCatching { JSONObject(it) }.getOrNull() }
        val theme = WidgetTheme(snapshot)
        val compact = LocalSize.current.width < 180.dp

        // Compact (small-size) widgets have no habit list to fill the cell,
        // so the header is vertically centered rather than pinned to the
        // top-left — leaving it there stranded a lot of dead background when
        // the user picks a tall-but-narrow cell size.
        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(day = theme.bg, night = theme.bg)
                .cornerRadius(20.dp)
                .clickable(onClick = openApp(context, headerUri(snapshot))),
            contentAlignment = if (compact) Alignment.CenterStart else Alignment.TopStart,
        ) {
            Column(modifier = GlanceModifier.padding(14.dp)) {
                HeaderRow(snapshot, theme)
                if (!compact) {
                    Spacer(modifier = GlanceModifier.height(10.dp))
                    HabitsList(snapshot, theme)
                }
            }
        }
    }

    @Composable
    private fun HeaderRow(snapshot: JSONObject?, theme: WidgetTheme) {
        val focusActive = snapshot?.optBoolean("focusActive", false) ?: false
        val eyebrow = if (focusActive) "FOCUSING" else "UP NEXT"
        val label = when {
            focusActive -> {
                val name = snapshot?.optString("focusLabel", "")
                if (!name.isNullOrEmpty()) name else "Focus session active"
            }
            else -> {
                val next = snapshot?.optString("nextActionTitle", "")
                if (!next.isNullOrEmpty()) next else "Nothing queued"
            }
        }
        Column {
            // Eyebrow — uppercase, letter-spaced, accent-colored (mirrors
            // the app's `Eyebrow` component), with a small accent tab under
            // it instead of the app's mono font (not bundled into the widget).
            Text(
                eyebrow,
                style = TextStyle(
                    color = solid(theme.accent),
                    fontSize = 10.5.sp,
                    fontWeight = FontWeight.Medium,
                ),
            )
            Spacer(modifier = GlanceModifier.height(4.dp))
            Box(
                modifier = GlanceModifier
                    .width(24.dp)
                    .height(3.dp)
                    .background(day = theme.accent, night = theme.accent)
                    .cornerRadius(2.dp),
            ) {}
            Spacer(modifier = GlanceModifier.height(8.dp))
            Text(
                label,
                maxLines = 2,
                style = TextStyle(
                    color = solid(theme.fg),
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Medium,
                ),
            )
        }
    }

    @Composable
    private fun HabitsList(snapshot: JSONObject?, theme: WidgetTheme) {
        val habits: JSONArray = snapshot?.optJSONArray("habits") ?: JSONArray()
        Column(modifier = GlanceModifier.fillMaxWidth()) {
            for (i in 0 until habits.length()) {
                val h = habits.optJSONObject(i) ?: continue
                val id = h.optString("id")
                val title = h.optString("title")
                val done = h.optBoolean("done", false)
                Row(
                    modifier = GlanceModifier
                        .fillMaxWidth()
                        .padding(vertical = 5.dp)
                        .clickable(
                            actionRunCallback<ToggleHabitAction>(
                                actionParametersOf(HABIT_ID_KEY to id),
                            ),
                        ),
                    verticalAlignment = Alignment.Vertical.CenterVertically,
                ) {
                    CheckBadge(done, theme)
                    Spacer(modifier = GlanceModifier.width(9.dp))
                    Text(
                        title,
                        maxLines = 1,
                        style = TextStyle(
                            color = solid(if (done) theme.fgMuted else theme.fg),
                            fontSize = 13.sp,
                        ),
                    )
                }
            }
            if (habits.length() == 0) {
                Text(
                    "No habits yet",
                    style = TextStyle(color = solid(theme.fgMuted), fontSize = 12.sp),
                )
            }
        }
    }

    /** Filled accent circle + check when done; a thin muted ring when not —
     * same "solid accent badge" language as the app's checkboxes/dots. */
    @Composable
    private fun CheckBadge(done: Boolean, theme: WidgetTheme) {
        Box(
            modifier = GlanceModifier
                .width(20.dp)
                .height(20.dp)
                .background(
                    day = if (done) theme.accent else theme.bg,
                    night = if (done) theme.accent else theme.bg,
                )
                .cornerRadius(10.dp),
            contentAlignment = Alignment.Center,
        ) {
            if (done) {
                Text("✓", style = TextStyle(color = solid(theme.accentInk), fontSize = 11.sp))
            } else {
                Box(
                    modifier = GlanceModifier
                        .width(20.dp)
                        .height(20.dp)
                        .background(day = theme.fgMuted, night = theme.fgMuted)
                        .cornerRadius(10.dp)
                        .padding(1.5.dp),
                ) {
                    Box(
                        modifier = GlanceModifier
                            .fillMaxSize()
                            .background(day = theme.bg, night = theme.bg)
                            .cornerRadius(9.dp),
                    ) {}
                }
            }
        }
    }
}

/** Whole-widget / header tap target: routes by current state, else just opens the app. */
private fun headerUri(snapshot: JSONObject?): Uri {
    val focusActive = snapshot?.optBoolean("focusActive", false) ?: false
    return if (focusActive) Uri.parse("lifeos://focus") else Uri.parse("lifeos://now")
}

/** Opens MainActivity with [uri] as the intent data — picked up by the app's
 * `app_links` listener (see `DeepLinkService`) for routing. */
private fun openApp(context: Context, uri: Uri) =
    actionStartActivity(
        Intent(Intent.ACTION_VIEW, uri, context, MainActivity::class.java),
    )

/** Habit-checkbox tap: fires a background broadcast to a headless Dart
 * isolate (see `widgetBackgroundCallback` in widget_sync_service.dart) — no
 * app UI opens. Only wired up for BOOLEAN habits (see `_topHabits`). */
class ToggleHabitAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        val habitId = parameters[HABIT_ID_KEY] ?: return
        val uri = Uri.parse("lifeos-widget://toggle-habit?id=$habitId")
        HomeWidgetBackgroundIntent.getBroadcast(context, uri).send()
    }
}
