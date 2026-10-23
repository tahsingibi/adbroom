package io.github.adbroom.launcher;

import android.content.Context;
import android.content.SharedPreferences;
import android.net.Uri;
import java.util.List;

final class OrderStore {
    static final Uri URI = Uri.parse("content://io.github.adbroom.launcher.order/apps");
    static final Object LOCK = new Object();
    static SharedPreferences preferences(Context context) { return context.getSharedPreferences("app-order", Context.MODE_PRIVATE); }
    static long revision(Context context) { return preferences(context).getLong("revision", 0); }
    static List<String> read(Context context) {
        try { return OrderLogic.parse(preferences(context).getString("order", "")); }
        catch (IllegalArgumentException corrupt) { return new java.util.ArrayList<>(); }
    }

    // A revision prevents a stale Mac editor from overwriting changes made on the TV.
    static String save(Context context, List<String> order, long expectedRevision) {
        return saveProfile(context, order, null, expectedRevision);
    }
    static String saveProfile(Context context, List<String> order, LauncherConfig config, long expectedRevision) {
        synchronized (LOCK) {
            if (expectedRevision != revision(context)) return "conflict";
            SharedPreferences.Editor edit = preferences(context).edit().putLong("revision", expectedRevision + 1);
            if (order != null) edit.putString("order", OrderLogic.encode(order));
            if (config != null) edit.putString("config", config.json.toString());
            if (!edit.commit()) return "error";
        }
        context.getContentResolver().notifyChange(URI, null);
        context.getContentResolver().notifyChange(LauncherConfig.URI, null);
        return "ok";
    }
}
