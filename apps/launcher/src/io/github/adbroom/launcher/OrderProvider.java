package io.github.adbroom.launcher;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.Binder;
import android.os.Bundle;
import android.os.Process;
import android.util.Base64;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Local ADB bridge. No sockets, network permissions, or background polling on TV. */
public final class OrderProvider extends ContentProvider {
    @Override public boolean onCreate() { return true; }

    private void enforceShell() {
        int uid = Binder.getCallingUid();
        // call() does not automatically enforce the provider's manifest permission.
        if (uid != 2000 && uid != 0 && uid != Process.myUid()) throw new SecurityException("ADB shell only");
    }

    @Override public Cursor query(Uri uri, String[] projection, String selection, String[] args, String sort) {
        enforceShell();
        if (LauncherConfig.URI.equals(uri)) {
            MatrixCursor cursor = new MatrixCursor(new String[]{"config64", "revision"});
            synchronized (OrderStore.LOCK) {
                cursor.addRow(new Object[]{Base64.encodeToString(LauncherConfig.read(getContext()).json.toString().getBytes(StandardCharsets.UTF_8), Base64.NO_WRAP), OrderStore.revision(getContext())});
            }
            return cursor;
        }
        if (!OrderStore.URI.equals(uri)) throw new IllegalArgumentException("Unknown URI");
        List<AppCatalog.Entry> apps = AppCatalog.load(getContext());
        Map<String, AppCatalog.Entry> byPackage = new HashMap<>();
        List<String> installed = new ArrayList<>();
        for (AppCatalog.Entry app : apps) { installed.add(app.pkg); byPackage.put(app.pkg, app); }
        MatrixCursor cursor = new MatrixCursor(new String[]{"package", "label64", "revision"});
        synchronized (OrderStore.LOCK) {
            long revision = OrderStore.revision(getContext());
            cursor.addRow(new Object[]{"__meta__", "", revision});
            LauncherConfig config = LauncherConfig.read(getContext());
            for (String pkg : OrderLogic.reconcile(OrderStore.read(getContext()), installed)) {
                String label = Base64.encodeToString(config.label(pkg, byPackage.get(pkg).label).getBytes(StandardCharsets.UTF_8), Base64.NO_WRAP);
                cursor.addRow(new Object[]{pkg, label, revision});
            }
        }
        cursor.setNotificationUri(getContext().getContentResolver(), OrderStore.URI);
        return cursor;
    }

    @Override public Bundle call(String method, String arg, Bundle extras) {
        enforceShell();
        if (arg == null || arg.length() > 131072) throw new IllegalArgumentException("Invalid request");
        int separator = arg.indexOf(':');
        if (separator < 1) throw new IllegalArgumentException("Missing revision");
        long expected = Long.parseLong(arg.substring(0, separator));
        List<String> installed = new ArrayList<>();
        for (AppCatalog.Entry entry : AppCatalog.load(getContext())) installed.add(entry.pkg);
        List<String> requested;
        LauncherConfig config = null;
        if ("setProfile".equals(method)) {
            try {
                String decoded = new String(Base64.decode(arg.substring(separator + 1), Base64.NO_WRAP), StandardCharsets.UTF_8);
                org.json.JSONObject profile = new org.json.JSONObject(decoded);
                config = new LauncherConfig(profile.getJSONObject("settings"));
                org.json.JSONArray array = profile.getJSONArray("order");
                StringBuilder encoded = new StringBuilder();
                for (int i = 0; i < array.length(); i++) { if (i > 0) encoded.append(','); encoded.append(array.getString(i)); }
                requested = OrderLogic.parse(encoded.toString());
            } catch (org.json.JSONException error) { throw new IllegalArgumentException("Invalid profile", error); }
        } else if ("setOrder".equals(method)) requested = OrderLogic.parse(arg.substring(separator + 1));
        else throw new IllegalArgumentException("Unknown method");
        if (!installed.containsAll(requested)) throw new IllegalArgumentException("App list changed; refresh first");
        Bundle result = new Bundle();
        result.putString("status", OrderStore.saveProfile(getContext(), OrderLogic.reconcile(requested, installed), config, expected));
        return result;
    }

    @Override public String getType(Uri uri) { return "vnd.android.cursor.dir/vnd.adbroom.app-order"; }
    @Override public Uri insert(Uri uri, ContentValues values) { throw new UnsupportedOperationException(); }
    @Override public int update(Uri uri, ContentValues values, String selection, String[] args) { throw new UnsupportedOperationException(); }
    @Override public int delete(Uri uri, String selection, String[] args) { throw new UnsupportedOperationException(); }
}
