package io.github.adbroom.launcher;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.Intent;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;
import java.util.Locale;

final class TvUi {
    static final int BG = Color.rgb(16,19,23), PANEL = Color.rgb(28,33,39), TEXT = Color.rgb(239,242,238), MUTED = Color.rgb(150,160,170);
    static Context localized(Context context) {
        String language = LauncherConfig.read(context).value("language");
        if ("system".equals(language)) return context;
        Configuration config = new Configuration(context.getResources().getConfiguration());
        config.setLocale(new Locale(language));
        return context.createConfigurationContext(config);
    }
    static String t(Context context, String tr, String en) { return "tr".equals(context.getResources().getConfiguration().locale.getLanguage()) ? tr : en; }
    static int dp(Context context, int value) { return Math.round(value * context.getResources().getDisplayMetrics().density); }
    static TextView text(Context context, String label, int size, int color) {
        TextView view = new TextView(context); view.setText(label); view.setTextSize(size); view.setTextColor(color); return view;
    }
    static GradientDrawable round(Context context, int fill, int stroke) {
        GradientDrawable bg = new GradientDrawable(); bg.setColor(fill); bg.setCornerRadius(dp(context,12)); bg.setStroke(dp(context,2),stroke); return bg;
    }
    static Button button(Context context, String label) {
        Button button = new Button(context); button.setText(label); button.setTextColor(TEXT); button.setTextSize(13); button.setAllCaps(false);
        button.setPadding(dp(context,16),0,dp(context,16),0); button.setMinHeight(0); button.setMinimumHeight(0);
        button.setBackground(round(context,PANEL,Color.TRANSPARENT));
        button.setOnFocusChangeListener((v,focus) -> {
            button.setBackground(round(context,focus ? accent(LauncherConfig.read(context)) : PANEL,Color.TRANSPARENT));
            button.setTextColor(focus ? BG : TEXT);
        });
        return button;
    }
    static int accent(LauncherConfig config) { return "blue".equals(config.value("accent")) ? 0xFF9DCCF5 : "amber".equals(config.value("accent")) ? 0xFFF0CF91 : 0xFFB6E3B2; }
    static void message(Context context, String tr, String en) { Toast.makeText(context,t(context,tr,en),Toast.LENGTH_LONG).show(); }
    static void system(Activity activity, String action) {
        try { activity.startActivity(new Intent(action)); }
        catch (RuntimeException error) {
            if (!android.provider.Settings.ACTION_SETTINGS.equals(action)) system(activity,android.provider.Settings.ACTION_SETTINGS);
            else message(activity,"Bu TV ayar ekranını desteklemiyor.","This TV does not support this settings screen.");
        }
    }
    interface TextResult { void accept(String value); }
    static void input(Activity activity, String title, String initial, int max, TextResult result) {
        EditText field = new EditText(activity); field.setSingleLine(true); field.setText(initial);
        field.setImeOptions(android.view.inputmethod.EditorInfo.IME_FLAG_NO_EXTRACT_UI | android.view.inputmethod.EditorInfo.IME_ACTION_DONE);
        field.setFilters(new android.text.InputFilter[]{new android.text.InputFilter.LengthFilter(max)});
        AlertDialog dialog = new AlertDialog.Builder(activity).setTitle(title).setView(field)
            .setNegativeButton(android.R.string.cancel,null).setPositiveButton(android.R.string.ok,(d,w)-> result.accept(field.getText().toString())).create();
        dialog.show(); field.requestFocus();
    }
}
