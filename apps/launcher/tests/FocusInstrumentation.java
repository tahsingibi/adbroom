package io.github.adbroom.launcher.tests;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewTreeObserver;
import android.widget.AdapterView;
import android.widget.LinearLayout;
import org.json.JSONObject;
import java.lang.reflect.Field;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.atomic.AtomicReference;

/** On-device regression: inspect every drawn frame during D-pad navigation. */
public final class FocusInstrumentation extends Instrumentation {
    private final AtomicReference<String> failure = new AtomicReference<>();
    private int frames;
    private Activity activity;

    @Override public void onCreate(Bundle arguments) { super.onCreate(arguments); start(); }

    @Override public void onStart() {
        Bundle result = new Bundle();
        SharedPreferences preferences = getTargetContext().getSharedPreferences("app-order", 0);
        String original = preferences.getString("config", "{}");
        try {
            for (String layout : new String[]{"grid", "row"}) {
                JSONObject config = new JSONObject(original);
                config.put("layout", layout).put("columns", 4).put("hidden", new org.json.JSONArray())
                    .put("groups", new JSONObject()).put("showFavorites", false).put("showSideloaded", true);
                preferences.edit().putString("config", config.toString()).commit();
                checkLayout(layout);
            }
            if (failure.get() != null) throw new AssertionError(failure.get());
            if (frames < 10) throw new AssertionError("Too few rendered frames: " + frames);
            result.putString("focus_status", "PASS: grid + row, rapid navigation, scrolling, focus loss/return, reordering; " + frames + " frames");
            finish(Activity.RESULT_OK, result);
        } catch (Throwable error) {
            result.putString("focus_status", "FAIL: " + error);
            finish(Activity.RESULT_CANCELED, result);
        } finally {
            preferences.edit().putString("config", original).commit();
        }
    }

    private void checkLayout(String layout) throws Exception {
        activity = startActivitySync(new Intent().setClassName("io.github.adbroom.launcher",
            "io.github.adbroom.launcher.HomeActivity").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK));
        Field field = activity.getClass().getDeclaredField("grid"); field.setAccessible(true);
        AdapterView<?> grid = (AdapterView<?>)field.get(activity);
        for (int attempt = 0; attempt < 100 && grid.getCount() < 5; attempt++) {
            SystemClock.sleep(100); waitForIdleSync();
        }
        if (grid.getCount() < 5) throw new AssertionError("Need at least 5 launchable apps for recycling coverage");
        Set<Integer> selected = new HashSet<>();
        ViewTreeObserver.OnDrawListener inspect = () -> {
            frames++;
            int highlighted = 0;
            for (int i = 0; i < grid.getChildCount(); i++) {
                View tile = grid.getChildAt(i);
                if (!(tile.getBackground() instanceof GradientDrawable)) continue;
                GradientDrawable background = (GradientDrawable)tile.getBackground();
                if (background.getColor().getDefaultColor() != Color.rgb(28, 33, 39)) {
                    highlighted++;
                    if (tile != grid.getSelectedView()) failure.compareAndSet(null, layout + ": stale card highlighted");
                }
            }
            boolean focused = activity.hasWindowFocus() && grid.hasFocus();
            if (highlighted > 1 || (!focused && highlighted != 0))
                failure.compareAndSet(null, layout + ": " + highlighted + " highlights, grid focus=" + focused);
            if (focused && grid.getSelectedView() != null && highlighted != 1)
                failure.compareAndSet(null, layout + ": selected card has no highlight");
            selected.add(grid.getSelectedItemPosition());
        };
        runOnMainSync(() -> {
            // A single grid row forces off-screen recycling with a small catalog.
            LinearLayout.LayoutParams params = (LinearLayout.LayoutParams)grid.getLayoutParams();
            params.height = Math.round(140 * activity.getResources().getDisplayMetrics().density);
            params.weight = 0; grid.setLayoutParams(params);
            grid.requestFocus(); grid.setSelection(0);
            grid.getViewTreeObserver().addOnDrawListener(inspect);
        });
        waitForIdleSync();
        for (int key : new int[]{KeyEvent.KEYCODE_DPAD_RIGHT, KeyEvent.KEYCODE_DPAD_DOWN,
                                KeyEvent.KEYCODE_DPAD_LEFT, KeyEvent.KEYCODE_DPAD_UP}) {
            for (int i = 0; i < 12; i++) sendKeyDownUpSync(key);
            waitForIdleSync();
        }
        // Gallery can coalesce rapid keys while its native scroll animation runs.
        // Also visit every position to guarantee rebinding/scrolling coverage.
        for (int position = 0; position < grid.getCount(); position++) {
            final int target = position;
            runOnMainSync(() -> grid.setSelection(target));
            SystemClock.sleep(220); waitForIdleSync();
        }
        // Leave app cards for the toolbar, then return to the selected card.
        runOnMainSync(() -> grid.focusSearch(View.FOCUS_UP).requestFocus());
        waitForIdleSync();
        runOnMainSync(grid::requestFocus);
        waitForIdleSync();
        sendKeyDownUpSync(KeyEvent.KEYCODE_MENU);
        for (int i = 0; i < 6; i++) sendKeyDownUpSync(KeyEvent.KEYCODE_DPAD_RIGHT);
        sendKeyDownUpSync(KeyEvent.KEYCODE_BACK);
        waitForIdleSync();
        runOnMainSync(() -> {
            grid.getViewTreeObserver().removeOnDrawListener(inspect);
            activity.finish();
        });
        waitForIdleSync();
        if (selected.size() < 3) throw new AssertionError(layout + ": navigation did not reach enough cards: " + selected);
        if (failure.get() != null) throw new AssertionError(failure.get());
    }
}
