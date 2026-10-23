package io.github.adbroom.launcher;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/** Pure ordering logic shared by the TV UI and ADB provider. */
public final class OrderLogic {
    private OrderLogic() {}

    public static boolean validPackage(String value) {
        return value != null && value.matches("[A-Za-z0-9_]+(\\.[A-Za-z0-9_]+)*");
    }

    public static List<String> parse(String value) {
        Set<String> unique = new LinkedHashSet<>();
        if (value != null && !value.isEmpty()) {
            for (String pkg : value.split(",", -1)) {
                if (!validPackage(pkg) || !unique.add(pkg)) {
                    throw new IllegalArgumentException("Invalid or duplicate package");
                }
            }
        }
        return new ArrayList<>(unique);
    }

    /** Removed apps disappear; newly installed apps follow the saved apps. */
    public static List<String> reconcile(List<String> saved, List<String> installed) {
        Set<String> remaining = new LinkedHashSet<>(installed);
        List<String> result = new ArrayList<>();
        for (String pkg : saved) if (remaining.remove(pkg)) result.add(pkg);
        result.addAll(remaining);
        return result;
    }

    public static boolean move(List<String> order, int from, int to) {
        if (from < 0 || to < 0 || from >= order.size() || to >= order.size() || from == to) return false;
        order.add(to, order.remove(from));
        return true;
    }

    public static List<String> mergeVisible(List<String> canonical, List<String> visible) {
        Set<String> subset = new java.util.HashSet<>(visible);
        List<String> result = new ArrayList<>();
        int next = 0;
        for (String pkg : canonical) result.add(subset.contains(pkg) ? visible.get(next++) : pkg);
        return result;
    }

    public static String encode(List<String> packages) {
        StringBuilder result = new StringBuilder();
        for (String pkg : packages) { if (result.length() > 0) result.append(','); result.append(pkg); }
        return result.toString();
    }
}
