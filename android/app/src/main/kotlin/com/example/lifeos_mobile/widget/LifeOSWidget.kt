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
private val NOW_TYPE_KEY = ActionParameters.Key<String>("nowType")
private val NOW_ID_KEY = ActionParameters.Key<String>("nowId")
private val NOW_MIN_KEY = ActionParameters.Key<String>("nowMinutes")
private val NOW_COUNT_KEY = ActionParameters.Key<String>("nowCount")

/** Reads the app's colours out of the snapshot (the new look, following the
 * person's appearance). Defaults are the dark new look, before the first sync. */
private class WidgetTheme(json: JSONObject?) {
    val bg = colorOf(json, "bgColor", 0xFF15171DL)
    val fg = colorOf(json, "textColor", 0xFFF4F2EDL)
    val fgMuted = colorOf(json, "mutedTextColor", 0xFFABAFBAL)
    // Marigold: free time only.
    val free = colorOf(json, "accentColor", 0xFFFFB23EL)

    private fun colorOf(json: JSONObject?, key: String, default: Long): Color =
        Color(json?.optLong(key, default)?.toInt() ?: default.toInt())
}

private fun solid(color: Color) = ColorProvider(color)

/** "45 min", "1 h", "1 h 30". */
private fun minutesLabel(m: Int): String = when {
    m < 60 -> "$m min"
    m % 60 == 0 -> "${m / 60} h"
    else -> "${m / 60} h ${(m % 60).toString().padStart(2, '0')}"
}

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
        val tall = LocalSize.current.height >= 200.dp

        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(day = theme.bg, night = theme.bg)
                .cornerRadius(24.dp)
                .clickable(onClick = openApp(context, headerUri(snapshot))),
            contentAlignment = if (compact) Alignment.CenterStart else Alignment.TopStart,
        ) {
            Column(modifier = GlanceModifier.padding(16.dp)) {
                Row(verticalAlignment = Alignment.Vertical.Top) {
                    Box(modifier = GlanceModifier.defaultWeight().padding(end = 8.dp)) {
                        HeaderRow(snapshot, theme)
                    }
                    PlusButton(context, theme)
                }
                PickButtons(snapshot, theme, compact)
                if (!compact && tall) {
                    Spacer(modifier = GlanceModifier.height(12.dp))
                    RoutinesList(snapshot, theme)
                }
            }
        }
    }

    @Composable
    private fun HeaderRow(snapshot: JSONObject?, theme: WidgetTheme) {
        val focusActive = snapshot?.optBoolean("focusActive", false) ?: false
        val free = if (snapshot == null || snapshot.isNull("freeMinutes")) 0 else snapshot.optInt("freeMinutes", 0)
        val eyebrow = when {
            focusActive -> "FOCUSING"
            free > 0 -> "FREE NOW · ${minutesLabel(free)}"
            else -> "NEXT"
        }
        val label = when {
            focusActive -> {
                val name = snapshot?.optString("focusLabel", "")
                if (!name.isNullOrEmpty()) name else "Focus session"
            }
            else -> {
                val next = snapshot?.optString("nextActionTitle", "")
                if (!next.isNullOrEmpty() && next != "null") next else "Open Ally to see your day"
            }
        }
        Column {
            Text(
                eyebrow,
                style = TextStyle(color = solid(if (free > 0 && !focusActive) theme.free else theme.fgMuted), fontSize = 12.sp, fontWeight = FontWeight.Medium),
            )
            Spacer(modifier = GlanceModifier.height(4.dp))
            Text(label, maxLines = 2, style = TextStyle(color = solid(theme.fg), fontSize = 19.sp, fontWeight = FontWeight.Medium))
        }
    }

    @Composable
    private fun RoutinesList(snapshot: JSONObject?, theme: WidgetTheme) {
        val habits: JSONArray = snapshot?.optJSONArray("habits") ?: JSONArray()
        if (habits.length() == 0) return
        Column(modifier = GlanceModifier.fillMaxWidth()) {
            Text("ROUTINES TODAY", style = TextStyle(color = solid(theme.fgMuted), fontSize = 11.sp, fontWeight = FontWeight.Medium))
            Spacer(modifier = GlanceModifier.height(4.dp))
            for (i in 0 until habits.length()) {
                val h = habits.optJSONObject(i) ?: continue
                val id = h.optString("id")
                val done = h.optBoolean("done", false)
                Row(
                    modifier = GlanceModifier
                        .fillMaxWidth()
                        .padding(vertical = 5.dp)
                        .clickable(actionRunCallback<ToggleHabitAction>(actionParametersOf(HABIT_ID_KEY to id))),
                    verticalAlignment = Alignment.Vertical.CenterVertically,
                ) {
                    CheckBadge(done, theme)
                    Spacer(modifier = GlanceModifier.width(9.dp))
                    Text(h.optString("title"), maxLines = 1, style = TextStyle(color = solid(if (done) theme.fgMuted else theme.fg), fontSize = 15.sp))
                }
            }
        }
    }

    /** Done, Later and Smaller on the pick (ALLY.md 5.2 #23): each runs in the
     * background like the same button in the app, without opening it. */
    @Composable
    private fun PickButtons(snapshot: JSONObject?, theme: WidgetTheme, compact: Boolean) {
        val type = snapshot?.optString("nextActionType", "") ?: ""
        val id = snapshot?.optString("nextActionRefId", "") ?: ""
        val focusActive = snapshot?.optBoolean("focusActive", false) ?: false
        if (focusActive || id.isEmpty() || id == "null" || type !in setOf("TASK", "HABIT", "PROJECT")) return
        val minutes = if (snapshot?.isNull("nextMinutes") != false) "" else snapshot.optInt("nextMinutes").toString()
        val count = if (snapshot?.isNull("nextCount") != false) "" else snapshot.optInt("nextCount").toString()
        val params = actionParametersOf(NOW_TYPE_KEY to type, NOW_ID_KEY to id, NOW_MIN_KEY to minutes, NOW_COUNT_KEY to count)
        Spacer(modifier = GlanceModifier.height(10.dp))
        Row(verticalAlignment = Alignment.Vertical.CenterVertically) {
            Box(
                modifier = GlanceModifier
                    .background(day = theme.fg, night = theme.fg)
                    .cornerRadius(20.dp)
                    .padding(horizontal = 18.dp, vertical = 9.dp)
                    .clickable(actionRunCallback<NowDoneAction>(params)),
            ) {
                Text("Done", style = TextStyle(color = solid(theme.bg), fontSize = 15.sp, fontWeight = FontWeight.Medium))
            }
            if (!compact) {
                Spacer(modifier = GlanceModifier.width(6.dp))
                Box(modifier = GlanceModifier.padding(horizontal = 10.dp, vertical = 9.dp).clickable(actionRunCallback<NowLaterAction>(params))) {
                    Text("Later", style = TextStyle(color = solid(theme.fg), fontSize = 15.sp))
                }
                Box(modifier = GlanceModifier.padding(horizontal = 10.dp, vertical = 9.dp).clickable(actionRunCallback<NowSmallerAction>(params))) {
                    Text("Smaller", style = TextStyle(color = solid(theme.fg), fontSize = 15.sp))
                }
            }
        }
    }

    /** + opens Talk, ready to type or speak (`lifeos://talk`). */
    @Composable
    private fun PlusButton(context: Context, theme: WidgetTheme) {
        Box(
            modifier = GlanceModifier
                .width(40.dp)
                .height(40.dp)
                .background(day = theme.fg, night = theme.fg)
                .cornerRadius(20.dp)
                .clickable(onClick = openApp(context, Uri.parse("lifeos://talk"))),
            contentAlignment = Alignment.Center,
        ) {
            Text("+", style = TextStyle(color = solid(theme.bg), fontSize = 22.sp, fontWeight = FontWeight.Medium))
        }
    }

    /** Filled check when done; a thin ring when not. Never red. */
    @Composable
    private fun CheckBadge(done: Boolean, theme: WidgetTheme) {
        Box(
            modifier = GlanceModifier
                .width(20.dp)
                .height(20.dp)
                .background(day = if (done) theme.fg else theme.fgMuted, night = if (done) theme.fg else theme.fgMuted)
                .cornerRadius(10.dp)
                .padding(if (done) 0.dp else 1.5.dp),
            contentAlignment = Alignment.Center,
        ) {
            if (done) {
                Text("✓", style = TextStyle(color = solid(theme.bg), fontSize = 11.sp))
            } else {
                Box(modifier = GlanceModifier.fillMaxSize().background(day = theme.bg, night = theme.bg).cornerRadius(9.dp)) {}
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

/** Done on the widget's Now pick: a background broadcast to the headless
 * Dart isolate (`widgetBackgroundCallback`, host `now-done`). */
class NowDoneAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        val id = parameters[NOW_ID_KEY] ?: return
        val type = parameters[NOW_TYPE_KEY] ?: "TASK"
        val m = parameters[NOW_MIN_KEY] ?: ""
        val c = parameters[NOW_COUNT_KEY] ?: ""
        val uri = Uri.parse("lifeos-widget://now-done?type=$type&id=$id&m=$m&c=$c")
        HomeWidgetBackgroundIntent.getBroadcast(context, uri).send()
    }
}

/** Later on the widget's pick (host `now-later`). */
class NowLaterAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val id = parameters[NOW_ID_KEY] ?: return
        val type = parameters[NOW_TYPE_KEY] ?: "TASK"
        HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("lifeos-widget://now-later?type=$type&id=$id")).send()
    }
}

/** Smaller on the widget's pick (host `now-smaller`). */
class NowSmallerAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val id = parameters[NOW_ID_KEY] ?: return
        val type = parameters[NOW_TYPE_KEY] ?: "TASK"
        HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("lifeos-widget://now-smaller?type=$type&id=$id")).send()
    }
}
