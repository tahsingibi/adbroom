package io.github.adbroom.launcher;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.database.ContentObserver;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.util.LruCache;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewTreeObserver;
import android.widget.BaseAdapter;
import android.widget.Button;
import android.widget.GridView;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextClock;
import android.widget.TextView;
import android.widget.Toast;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Native, recycled grid. No WebView, SDK, network, database, or continuous background work. */
public final class HomeActivity extends Activity {
    private static final int BG = Color.rgb(16, 19, 23);
    private static final int PANEL = Color.rgb(28, 33, 39);
    private static final int TEXT = Color.rgb(239, 242, 238);
    private static final int MUTED = Color.rgb(143, 153, 163);
    private final Handler main = new Handler(Looper.getMainLooper());
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private final LruCache<String, Drawable> icons = new LruCache<>(80);
    private final List<AppCatalog.Entry> entries = new ArrayList<>();
    private final List<String> order = new ArrayList<>();
    private final Map<String, AppCatalog.Entry> byPackage = new HashMap<>();
    private android.widget.AdapterView grid;
    private LinearLayout root;
    private LinearLayout favorites;
    private LinearLayout groups;
    private TextClock clock;
    private TextClock date;
    private TextView greeting;
    private HomeModules modules;
    private LauncherConfig config;
    private String selectedGroup = "";
    private final List<String> allOrder = new ArrayList<>();
    private boolean active;
    private long wallpaperStamp = -1;
    private android.graphics.drawable.Drawable wallpaper;

    @Override protected void attachBaseContext(Context base) { super.attachBaseContext(TvUi.localized(base)); }
    private TextView hint;
    private Button rearrange;
    private AppAdapter adapter;
    private boolean editing;
    private int editPosition;
    private boolean loading;
    private boolean reloadPending;
    private boolean saving;
    private boolean destroyed;
    private long editRevision;
    private int columns;
    private boolean receiverRegistered;
    // AdapterView can rebind recycled children after onItemSelected. Reconcile
    // with its actual selected view after layout, before a frame is drawn.
    private final ViewTreeObserver.OnPreDrawListener focusBeforeDraw = () -> {
        updateFocus();
        return true;
    };

    private final ContentObserver observer = new ContentObserver(main) {
        @Override public void onChange(boolean selfChange) {
            if (!active) return;
            if (editing) {
                editing = false;
                Toast.makeText(HomeActivity.this, R.string.changed, Toast.LENGTH_SHORT).show();
            }
            applyOrder();
        }
    };
    private final BroadcastReceiver packagesChanged = new BroadcastReceiver() {
        @Override public void onReceive(Context context, Intent intent) { icons.evictAll(); loadApps(); }
    };

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_FULLSCREEN
                | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
        config = LauncherConfig.read(this);
        columns = getResources().getConfiguration().screenWidthDp >= 1100 ? 7 : 6;
        root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(48), dp(30), dp(48), dp(20));
        root.setBackgroundColor(BG);

        LinearLayout header = new LinearLayout(this);
        header.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout wordmark = new LinearLayout(this);
        wordmark.setOrientation(LinearLayout.VERTICAL);
        TextView brand = text("adbroom", 30, TEXT);
        brand.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
        brand.setLetterSpacing(-0.04f);
        wordmark.addView(brand);
        greeting = text(getString(R.string.tagline), 12, MUTED);
        wordmark.addView(greeting);
        header.addView(wordmark, new LinearLayout.LayoutParams(0, -2, 1));
        clock = new TextClock(this);
        clock.setTextColor(TEXT);
        clock.setTextSize(26);
        clock.setFormat12Hour("h:mm");
        clock.setFormat24Hour("HH:mm");
        clock.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        LinearLayout status = new LinearLayout(this);
        status.setOrientation(LinearLayout.VERTICAL);
        status.setGravity(Gravity.END);
        status.addView(clock);
        date = new TextClock(this);
        date.setTextColor(MUTED); date.setTextSize(11);
        date.setFormat12Hour("EEE, d MMM"); date.setFormat24Hour("EEE, d MMM");
        status.addView(date);
        TextView network = text("", 11, MUTED);
        status.addView(network);
        header.addView(status);
        root.addView(header);
        LinearLayout moduleRow = new LinearLayout(this);
        moduleRow.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout inputs = new LinearLayout(this);
        android.widget.HorizontalScrollView inputScroll = new android.widget.HorizontalScrollView(this);
        inputScroll.setHorizontalScrollBarEnabled(false); inputScroll.addView(inputs);
        moduleRow.addView(inputScroll, new LinearLayout.LayoutParams(0, -2, 1));
        Button media = action(""); media.setSingleLine(true); media.setEllipsize(android.text.TextUtils.TruncateAt.END); media.setMaxWidth(dp(340));
        moduleRow.addView(media, new LinearLayout.LayoutParams(-2, dp(36)));
        LinearLayout.LayoutParams moduleParams = new LinearLayout.LayoutParams(-1, -2); moduleParams.topMargin = dp(12); root.addView(moduleRow, moduleParams);
        modules = new HomeModules(this, network, inputs, media);
        favorites = new LinearLayout(this);
        android.widget.HorizontalScrollView favoriteScroll = new android.widget.HorizontalScrollView(this);
        favoriteScroll.setHorizontalScrollBarEnabled(false); favoriteScroll.addView(favorites);
        LinearLayout.LayoutParams favoriteParams = new LinearLayout.LayoutParams(-1, -2); favoriteParams.topMargin = dp(10); root.addView(favoriteScroll, favoriteParams);

        LinearLayout toolbar = new LinearLayout(this);
        toolbar.setGravity(Gravity.CENTER_VERTICAL);
        toolbar.setPadding(0, dp(22), 0, dp(12));
        TextView heading = text(getString(R.string.apps), 17, TEXT);
        toolbar.addView(heading, new LinearLayout.LayoutParams(0, -2, 1));
        rearrange = action(getString(R.string.reorder));
        rearrange.setOnClickListener(v -> { if (editing) finishEditing(); else PinGate.admin(this, () -> beginEditing()); });
        toolbar.addView(rearrange);
        Button settings = action(getString(R.string.settings));
        settings.setOnClickListener(v -> PinGate.admin(this, () -> startActivity(new Intent(this, LauncherSettingsActivity.class))));
        LinearLayout.LayoutParams settingsParams = new LinearLayout.LayoutParams(-2, dp(38));
        settingsParams.setMarginStart(dp(12));
        toolbar.addView(settings, settingsParams);
        root.addView(toolbar);

        groups = new LinearLayout(this);
        android.widget.HorizontalScrollView groupScroll = new android.widget.HorizontalScrollView(this);
        groupScroll.setHorizontalScrollBarEnabled(false); groupScroll.addView(groups); root.addView(groupScroll);
        columns = config.json.optInt("columns", 6);
        if ("row".equals(config.value("layout"))) {
            android.widget.Gallery row = new android.widget.Gallery(this);
            row.setSpacing(dp(14)); row.setUnselectedAlpha(1f); row.setGravity(Gravity.CENTER_VERTICAL);
            grid = row;
        } else {
            GridView view = new GridView(this);
            view.setNumColumns(columns); view.setHorizontalSpacing(dp(14)); view.setVerticalSpacing(dp(14));
            view.setStretchMode(GridView.STRETCH_COLUMN_WIDTH); view.setSelector(android.R.color.transparent); view.setDrawSelectorOnTop(false);
            grid = view;
        }
        grid.setClipToPadding(false); grid.setPadding(dp(5), dp(5), dp(5), dp(10)); grid.setVerticalScrollBarEnabled(false);
        grid.setOnItemClickListener((parent, view, position, id) -> {
            if (saving) return;
            if (editing) { finishEditing(); return; }
            launchPackage(order.get(position));
        });
        grid.setOnItemLongClickListener((parent, view, position, id) -> {
            AppCatalog.Entry app = byPackage.get(order.get(position));
            AppActions.show(this, app, worker, () -> beginEditing(app.pkg));
            return true;
        });
        grid.setOnItemSelectedListener(new android.widget.AdapterView.OnItemSelectedListener() {
            public void onItemSelected(android.widget.AdapterView<?> parent, View view, int position, long id) { updateFocus(); }
            public void onNothingSelected(android.widget.AdapterView<?> parent) { updateFocus(); }
        });
        grid.setOnFocusChangeListener((view, focused) -> updateFocus());
        grid.getViewTreeObserver().addOnPreDrawListener(focusBeforeDraw);
        adapter = new AppAdapter();
        grid.setAdapter(adapter);
        root.addView(grid, new LinearLayout.LayoutParams(-1, 0, 1));
        hint = text(getString(R.string.loading), 12, MUTED);
        hint.setPadding(0, dp(14), 0, 0);
        root.addView(hint);
        setContentView(root);
        getContentResolver().registerContentObserver(OrderStore.URI, false, observer);
        IntentFilter filter = new IntentFilter();
        filter.addAction(Intent.ACTION_PACKAGE_ADDED);
        filter.addAction(Intent.ACTION_PACKAGE_REMOVED);
        filter.addAction(Intent.ACTION_PACKAGE_CHANGED);
        filter.addAction(Intent.ACTION_PACKAGE_REPLACED);
        filter.addDataScheme("package");
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(packagesChanged, filter, Context.RECEIVER_NOT_EXPORTED);
        else registerReceiver(packagesChanged, filter);
        receiverRegistered = true;
        loadApps();
    }

    @Override protected void onResume() {
        super.onResume(); active = true;
        if (adapter != null && !editing) applyOrder();
    }
    @Override protected void onPause() {
        active = false; if (modules != null) modules.stop();
        updateFocus();
        if (config != null && config.flag("rememberFocus") && selectedPackage() != null)
            getSharedPreferences("focus", MODE_PRIVATE).edit().putString("last", selectedPackage()).apply();
        super.onPause();
    }

    @Override public void onWindowFocusChanged(boolean focused) {
        super.onWindowFocusChanged(focused);
        updateFocus();
    }

    private void launchPackage(String pkg) {
        AppCatalog.Entry app = byPackage.get(pkg); if (app == null) return;
        PinGate.require(this, PinGate.locked(this, pkg), () -> {
            try { startActivity(new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                .setComponent(app.component).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)); }
            catch (RuntimeException error) { toast(R.string.open_failed); loadApps(); }
        });
    }

    private void loadApps() {
        if (destroyed) return;
        if (loading) { reloadPending = true; return; }
        loading = true;
        worker.execute(() -> {
            List<AppCatalog.Entry> loaded = AppCatalog.load(this);
            main.post(() -> {
                loading = false;
                if (destroyed) return;
                editing = false;
                entries.clear(); entries.addAll(loaded);
                byPackage.clear();
                for (AppCatalog.Entry entry : entries) byPackage.put(entry.pkg, entry);
                applyOrder();
                grid.requestFocus();
                if (reloadPending) { reloadPending = false; loadApps(); }
            });
        });
    }

    private void applyOrder() {
        LauncherConfig next = LauncherConfig.read(this);
        if (!next.value("layout").equals(config.value("layout")) || !next.value("language").equals(config.value("language"))) { recreate(); return; }
        config = next; columns = config.json.optInt("columns",6);
        if (grid instanceof GridView) ((GridView)grid).setNumColumns(columns);
        String selected = selectedPackage();
        if (selected == null && config.flag("rememberFocus")) selected = getSharedPreferences("focus", MODE_PRIVATE).getString("last",null);
        List<String> installed = new ArrayList<>();
        for (AppCatalog.Entry entry : entries) installed.add(entry.pkg);
        synchronized (OrderStore.LOCK) {
            allOrder.clear(); allOrder.addAll(OrderLogic.reconcile(OrderStore.read(this), installed));
        }
        java.util.Set<String> folders = new java.util.TreeSet<>();
        for (String pkg : allOrder) if (!config.includes("hidden",pkg) && !config.group(pkg).isEmpty()) folders.add(config.group(pkg));
        if (!selectedGroup.isEmpty() && !folders.contains(selectedGroup)) selectedGroup = "";
        order.clear();
        for (String pkg : allOrder) {
            AppCatalog.Entry entry = byPackage.get(pkg);
            if (!config.includes("hidden",pkg) && (config.flag("showSideloaded") || entry.television)
                    && (selectedGroup.isEmpty() || selectedGroup.equals(config.group(pkg)))) order.add(pkg);
        }
        groups.removeAllViews();
        if (!folders.isEmpty()) {
            groupButton("", TvUi.t(this,"Tümü","All"));
            for (String folder : folders) groupButton(folder,folder);
        }
        favorites.removeAllViews();
        if (config.flag("showFavorites")) for (String pkg : allOrder) {
            if (!config.includes("favorites",pkg) || config.includes("hidden",pkg) || (!config.flag("showSideloaded") && !byPackage.get(pkg).television)) continue;
            Button button = action("★ " + config.label(pkg,byPackage.get(pkg).label));
            button.setOnClickListener(v -> launchPackage(pkg));
            button.setOnLongClickListener(v -> { AppActions.show(this,byPackage.get(pkg),worker,null); return true; });
            LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(-2,dp(36)); params.setMarginEnd(dp(10)); favorites.addView(button,params);
        }
        greeting.setText(config.value("profileName").isEmpty() ? getString(R.string.tagline) : TvUi.t(this,"Merhaba, ","Hello, ")+config.value("profileName"));
        clock.setVisibility(config.flag("showClock") ? View.VISIBLE : View.GONE);
        clock.setFormat12Hour(config.flag("use24Hour") ? "HH:mm" : "h:mm a");
        clock.setFormat24Hour(config.flag("use24Hour") ? "HH:mm" : "h:mm a");
        date.setVisibility(config.flag("showDate") ? View.VISIBLE : View.GONE);
        applyBackground();
        if (active) modules.start(config);
        updateHint(); adapter.notifyDataSetChanged();
        if (selected != null && order.contains(selected)) grid.setSelection(order.indexOf(selected));
    }
    private void groupButton(String key,String label) {
        Button button = action(key.equals(selectedGroup) ? "• " + label : label);
        button.setOnClickListener(v -> { selectedGroup = key; applyOrder(); grid.requestFocus(); });
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(-2,dp(34)); params.setMarginEnd(dp(8)); params.bottomMargin=dp(8); groups.addView(button,params);
    }
    private void applyBackground() {
        java.io.File file = new java.io.File(getFilesDir(),"wallpaper.jpg"); long stamp=file.exists()?file.lastModified():0;
        if (stamp != wallpaperStamp) {
            wallpaperStamp=stamp; wallpaper=null;
            if (stamp>0) worker.execute(() -> {
                android.graphics.Bitmap bitmap=android.graphics.BitmapFactory.decodeFile(file.getPath());
                if (bitmap!=null) {
                    android.graphics.drawable.BitmapDrawable image=new android.graphics.drawable.BitmapDrawable(getResources(),bitmap);
                    image.setGravity(Gravity.FILL); image.setColorFilter(new android.graphics.LightingColorFilter(0x00888888,0));
                    main.post(() -> { if (!destroyed && wallpaperStamp==stamp) { wallpaper=image; root.setBackground(image); } });
                }
            });
        }
        if (wallpaper!=null) {root.setBackground(wallpaper);return;}
        int top="forest".equals(config.value("theme"))?0xFF1B302B:"warm".equals(config.value("theme"))?0xFF30271F:0xFF18202C;
        root.setBackground(new GradientDrawable(GradientDrawable.Orientation.TL_BR,new int[]{top,BG}));
    }

    private String selectedPackage() {
        int position = grid == null ? -1 : grid.getSelectedItemPosition();
        return position >= 0 && position < order.size() ? order.get(position) : null;
    }

    private void beginEditing() { beginEditing(null); }
    private void beginEditing(String preferredPackage) {
        if (order.isEmpty() || saving || editing) return;
        // Capture order and revision atomically, including a just-arrived Mac update.
        synchronized (OrderStore.LOCK) {
            applyOrder();
            editRevision = OrderStore.revision(this);
        }
        editPosition = Math.max(0, preferredPackage == null ? grid.getSelectedItemPosition() : order.indexOf(preferredPackage));
        editing = true;
        updateHint();
        grid.requestFocus();
        grid.setSelection(editPosition);
        updateFocus();
    }

    private void finishEditing() {
        if (!editing || saving) return;
        String selected = order.isEmpty() ? null : order.get(editPosition);
        if (selected != null && config.flag("rememberFocus")) getSharedPreferences("focus", MODE_PRIVATE).edit().putString("last",selected).apply();
        editing = false;
        saving = true;
        updateHint();
        List<String> pending = OrderLogic.mergeVisible(allOrder, order);
        long revision = editRevision;
        worker.execute(() -> {
            String result = OrderStore.save(this, pending, revision);
            main.post(() -> {
                saving = false;
                if (destroyed) return;
                if ("conflict".equals(result)) toast(R.string.changed);
                else if (!"ok".equals(result)) toast(R.string.save_failed);
                applyOrder();
            });
        });
    }

    private void updateHint() {
        rearrange.setText(editing ? R.string.done : R.string.reorder);
        hint.setText(editing ? R.string.moving : order.isEmpty() ? (loading ? R.string.loading : R.string.empty) : R.string.hint);
        hint.setTextColor(editing ? TvUi.accent(config) : MUTED);
    }

    @Override public boolean dispatchKeyEvent(KeyEvent event) {
        int key = event.getKeyCode();
        if (key == KeyEvent.KEYCODE_MENU) {
            if (event.getAction() == KeyEvent.ACTION_UP) { if (editing) finishEditing(); else PinGate.admin(this, () -> beginEditing()); }
            return true;
        }
        if (editing && (key == KeyEvent.KEYCODE_DPAD_CENTER || key == KeyEvent.KEYCODE_ENTER || key == KeyEvent.KEYCODE_NUMPAD_ENTER)) {
            if (event.getAction() == KeyEvent.ACTION_UP) finishEditing();
            return true;
        }
        if (editing && key == KeyEvent.KEYCODE_BACK) {
            if (event.getAction() == KeyEvent.ACTION_UP) { editing = false; applyOrder(); }
            return true;
        }
        if (editing && (key == KeyEvent.KEYCODE_DPAD_LEFT || key == KeyEvent.KEYCODE_DPAD_RIGHT
                || key == KeyEvent.KEYCODE_DPAD_UP || key == KeyEvent.KEYCODE_DPAD_DOWN)) {
            if (event.getAction() == KeyEvent.ACTION_DOWN) {
                int from = editPosition;
                int step = "row".equals(config.value("layout")) ? 1 : columns;
                int to = from + (key == KeyEvent.KEYCODE_DPAD_LEFT ? -1 : key == KeyEvent.KEYCODE_DPAD_RIGHT ? 1
                        : key == KeyEvent.KEYCODE_DPAD_UP ? -step : step);
                if (OrderLogic.move(order, from, to)) { editPosition = to; adapter.notifyDataSetChanged(); grid.setSelection(to); updateFocus(); }
            }
            return true;
        }
        return super.dispatchKeyEvent(event);
    }

    @Override public void onBackPressed() {
        // A HOME activity stays at home; avoid falling through to the stock launcher.
        if (editing) { editing = false; applyOrder(); }
        else { grid.requestFocus(); grid.setSelection(0); }
    }

    @Override protected void onDestroy() {
        destroyed = true;
        if (grid != null && grid.getViewTreeObserver().isAlive())
            grid.getViewTreeObserver().removeOnPreDrawListener(focusBeforeDraw);
        getContentResolver().unregisterContentObserver(observer);
        if (receiverRegistered) unregisterReceiver(packagesChanged);
        if (modules != null) modules.stop();
        worker.shutdown();
        main.removeCallbacksAndMessages(null);
        super.onDestroy();
    }

    private final class AppAdapter extends BaseAdapter {
        @Override public int getCount() { return order.size(); }
        @Override public Object getItem(int position) { return order.get(position); }
        @Override public long getItemId(int position) { return position; }
        @Override public View getView(int position, View recycled, ViewGroup parent) {
            Tile tile = recycled instanceof Tile ? (Tile) recycled : new Tile();
            String pkg = order.get(position);
            AppCatalog.Entry entry = byPackage.get(pkg);
            tile.boundPackage = pkg;
            tile.label.setText(config.label(pkg, entry.label));
            tile.label.setVisibility(config.flag("showLabels") ? View.VISIBLE : View.GONE);
            tile.setLayoutParams(parent instanceof android.widget.Gallery ? new android.widget.Gallery.LayoutParams(dp(160),dp(116)) : new GridView.LayoutParams(-1,dp(116)));
            tile.icon.setLayoutParams(new LinearLayout.LayoutParams(dp("banner".equals(config.value("cardStyle")) ? 104 : 54),dp(54)));
            tile.setContentDescription(config.label(pkg, entry.label));
            // A recycled tile must never inherit the previous package's focus.
            // The pre-draw pass assigns focus once AdapterView finishes layout.
            styleTile(tile, false);
            String cacheKey = config.value("cardStyle") + ":" + pkg;
            tile.boundKey = cacheKey;
            boolean banner = "banner".equals(config.value("cardStyle"));
            Drawable icon = icons.get(cacheKey);
            tile.icon.setImageDrawable(icon == null ? getDrawable(R.drawable.launcher_icon) : icon);
            if (icon == null && !tile.pendingPackage.equals(cacheKey)) {
                tile.pendingPackage = cacheKey;
                worker.execute(() -> {
                    Drawable loaded;
                    try { loaded = banner ? entry.info.activityInfo.loadBanner(getPackageManager()) : null;
                        if (loaded == null) loaded = entry.info.loadIcon(getPackageManager()); }
                    catch (RuntimeException error) { loaded = getDrawable(R.drawable.launcher_icon); }
                    final Drawable result = loaded;
                    icons.put(cacheKey, result);
                    main.post(() -> {
                        if (!destroyed && pkg.equals(tile.boundPackage) && cacheKey.equals(tile.boundKey)) { tile.icon.setImageDrawable(result); tile.pendingPackage = ""; }
                    });
                });
            }
            return tile;
        }
    }

    private final class Tile extends LinearLayout {
        final ImageView icon;
        final TextView label;
        String boundPackage = "";
        String boundKey = "";
        String pendingPackage = "";
        final GradientDrawable cardBackground;
        int appliedFill = Integer.MIN_VALUE;
        int appliedBorder = Integer.MIN_VALUE;
        int appliedLabel = Integer.MIN_VALUE;
        Tile() {
            super(HomeActivity.this);
            setOrientation(VERTICAL);
            setGravity(Gravity.CENTER);
            setPadding(dp(10), dp(14), dp(10), dp(10));
            setLayoutParams(new GridView.LayoutParams(-1, dp(116)));
            cardBackground = round(PANEL, Color.TRANSPARENT);
            setBackground(cardBackground);
            icon = new ImageView(HomeActivity.this);
            icon.setScaleType(ImageView.ScaleType.FIT_CENTER);
            addView(icon, new LinearLayout.LayoutParams(dp(54), dp(54)));
            label = text("", 12, TEXT);
            label.setMaxLines(1);
            label.setEllipsize(android.text.TextUtils.TruncateAt.END);
            label.setGravity(Gravity.CENTER);
            LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(-1, -2);
            params.topMargin = dp(12);
            addView(label, params);
        }
    }

    private void updateFocus() {
        if (grid == null) return;
        View selected = active && hasWindowFocus() && grid.hasFocus() ? grid.getSelectedView() : null;
        int position = editing ? editPosition : grid.getSelectedItemPosition();
        String selectedPackage = position >= 0 && position < order.size() ? order.get(position) : null;
        for (int child = 0; child < grid.getChildCount(); child++) {
            View view = grid.getChildAt(child);
            if (view instanceof Tile) styleTile((Tile) view,
                    view == selected && ((Tile) view).boundPackage.equals(selectedPackage));
        }
    }
    private void styleTile(Tile tile, boolean focused) {
        int fill = focused ? (editing ? TvUi.accent(config) : Color.rgb(48, 59, 54)) : PANEL;
        int border = focused ? TvUi.accent(config) : Color.TRANSPARENT;
        int label = focused && editing ? BG : TEXT;
        // The pre-draw check allocates nothing and invalidates only changed cards.
        if (tile.appliedFill == fill && tile.appliedBorder == border && tile.appliedLabel == label) return;
        tile.appliedFill = fill; tile.appliedBorder = border; tile.appliedLabel = label;
        tile.cardBackground.setColor(fill);
        tile.cardBackground.setStroke(dp(2), border);
        tile.label.setTextColor(label);
    }

    private Button action(String label) {
        Button button = new Button(this);
        button.setText(label);
        button.setTextSize(12);
        button.setTextColor(TEXT);
        button.setAllCaps(false);
        button.setMinHeight(0);
        button.setMinimumHeight(0);
        button.setPadding(dp(16), 0, dp(16), 0);
        button.setBackground(round(PANEL, Color.TRANSPARENT));
        button.setOnFocusChangeListener((view, focused) -> {
            button.setBackground(round(focused ? TvUi.accent(config) : PANEL, Color.TRANSPARENT));
            button.setTextColor(focused ? BG : TEXT);
        });
        button.setLayoutParams(new LinearLayout.LayoutParams(-2, dp(38)));
        return button;
    }
    private TextView text(String value, int size, int color) {
        TextView view = new TextView(this);
        view.setText(value); view.setTextSize(size); view.setTextColor(color);
        return view;
    }
    private GradientDrawable round(int fill, int border) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(fill); drawable.setCornerRadius(dp(12)); drawable.setStroke(dp(2), border);
        return drawable;
    }
    private int dp(int value) { return Math.round(value * getResources().getDisplayMetrics().density); }
    private void toast(int resource) { Toast.makeText(this, resource, Toast.LENGTH_SHORT).show(); }
}
