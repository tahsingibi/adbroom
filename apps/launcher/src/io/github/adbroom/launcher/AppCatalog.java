package io.github.adbroom.launcher;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

final class AppCatalog {
    static final class Entry {
        final boolean television;
        final String pkg;
        final String label;
        final ComponentName component;
        final ResolveInfo info;
        Entry(ResolveInfo ri, PackageManager pm, boolean tv) {
            television = tv;
            pkg = ri.activityInfo.packageName;
            label = ri.loadLabel(pm).toString();
            component = new ComponentName(pkg, ri.activityInfo.name);
            info = ri;
        }
    }

    static List<Entry> load(Context context) {
        PackageManager pm = context.getPackageManager();
        Map<String, Entry> entries = new LinkedHashMap<>();
        // Prefer TV activities; include sideloaded apps with only a regular launcher activity.
        for (String category : new String[]{Intent.CATEGORY_LEANBACK_LAUNCHER, Intent.CATEGORY_LAUNCHER}) {
            Intent intent = new Intent(Intent.ACTION_MAIN).addCategory(category);
            for (ResolveInfo ri : pm.queryIntentActivities(intent, 0)) {
                if (!ri.activityInfo.enabled || !ri.activityInfo.exported
                        || context.getPackageName().equals(ri.activityInfo.packageName)) continue;
                if (!entries.containsKey(ri.activityInfo.packageName)) entries.put(ri.activityInfo.packageName, new Entry(ri, pm, Intent.CATEGORY_LEANBACK_LAUNCHER.equals(category)));
            }
        }
        List<Entry> result = new ArrayList<>(entries.values());
        java.util.Collections.sort(result, (a, b) -> {
            int label = a.label.compareToIgnoreCase(b.label);
            return label == 0 ? a.pkg.compareTo(b.pkg) : label;
        });
        return result;
    }
}
