package io.github.adbroom.launcher;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import android.content.Context;
import android.net.Uri;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/** Versioned, bounded settings. PIN material is deliberately kept outside the ADB profile. */
final class LauncherConfig {
    static final Uri URI = Uri.parse("content://io.github.adbroom.launcher.order/settings");
    final JSONObject json;
    LauncherConfig(JSONObject source) throws JSONException {
        json = new JSONObject();
        json.put("schema", 1);
        if (source.optInt("schema", 1) != 1) throw new IllegalArgumentException("Unsupported settings schema");
        int columns = source.optInt("columns", 6);
        if (columns < 4 || columns > 8) throw new IllegalArgumentException("Columns must be 4–8");
        json.put("columns", columns);
        choice(source, "layout", "grid", "grid", "row");
        choice(source, "theme", "midnight", "midnight", "forest", "warm");
        choice(source, "accent", "sage", "sage", "blue", "amber");
        choice(source, "cardStyle", "icon", "icon", "banner");
        choice(source, "language", "system", "system", "en", "tr");
        for (String key : new String[]{"showClock", "use24Hour", "showDate", "showNetwork", "showInputs",
                "hideDisconnectedInputs", "showFavorites", "showLabels", "rememberFocus", "showSideloaded"}) json.put(key, source.optBoolean(key, true));
        json.put("showMedia", source.optBoolean("showMedia", false));
        json.put("profileName", bounded(source.optString("profileName", ""), 40));
        for (String key : new String[]{"favorites", "hidden"}) {
            JSONArray input = source.optJSONArray(key), output = new JSONArray();
            Set<String> seen = new HashSet<>();
            if (input != null) for (int i = 0; i < input.length(); i++) {
                String pkg = input.getString(i);
                if (!OrderLogic.validPackage(pkg) || !seen.add(pkg) || i >= 512) throw new IllegalArgumentException("Invalid app list");
                output.put(pkg);
            }
            json.put(key, output);
        }
        for (String key : new String[]{"labels", "groups"}) {
            JSONObject input = source.optJSONObject(key), output = new JSONObject();
            if (input != null) {
                java.util.Iterator<String> names = input.keys();
                int count = 0;
                while (names.hasNext()) {
                    String pkg = names.next();
                    if (!OrderLogic.validPackage(pkg) || count++ >= 512) throw new IllegalArgumentException("Invalid app customization");
                    String value = bounded(input.getString(pkg), key.equals("labels") ? 60 : 30).trim();
                    if (!value.isEmpty()) output.put(pkg, value);
                }
            }
            json.put(key, output);
        }
    }
    private void choice(JSONObject source, String key, String fallback, String... choices) throws JSONException {
        String value = source.optString(key, fallback);
        for (String choice : choices) if (choice.equals(value)) { json.put(key, value); return; }
        throw new IllegalArgumentException("Invalid " + key);
    }
    private static String bounded(String value, int max) {
        if (value.length() > max || value.indexOf('\0') >= 0) throw new IllegalArgumentException("Text too long");
        return value;
    }
    static LauncherConfig read(Context context) {
        try { return new LauncherConfig(new JSONObject(OrderStore.preferences(context).getString("config", "{}"))); }
        catch (Exception error) {
            try { return new LauncherConfig(new JSONObject()); }
            catch (JSONException impossible) { throw new IllegalStateException(impossible); }
        }
    }
    boolean flag(String key) { return json.optBoolean(key); }
    String value(String key) { return json.optString(key); }
    boolean includes(String key, String pkg) {
        JSONArray values = json.optJSONArray(key);
        for (int i = 0; i < values.length(); i++) if (pkg.equals(values.optString(i))) return true;
        return false;
    }
    String label(String pkg, String fallback) { return json.optJSONObject("labels").optString(pkg, fallback); }
    String group(String pkg) { return json.optJSONObject("groups").optString(pkg, ""); }
    void set(String key, Object value) { try { json.put(key, value); } catch (JSONException error) { throw new IllegalArgumentException(error); } }
    void toggleApp(String key, String pkg) {
        JSONArray result = new JSONArray();
        boolean exists = includes(key, pkg);
        JSONArray old = json.optJSONArray(key);
        for (int i = 0; i < old.length(); i++) if (!pkg.equals(old.optString(i))) result.put(old.optString(i));
        if (!exists) result.put(pkg);
        set(key, result);
    }
    void setAppText(String key, String pkg, String value) {
        try {
            JSONObject map = json.getJSONObject(key);
            if (value.trim().isEmpty()) map.remove(pkg); else map.put(pkg, value.trim());
        } catch (JSONException error) { throw new IllegalArgumentException(error); }
    }
}
