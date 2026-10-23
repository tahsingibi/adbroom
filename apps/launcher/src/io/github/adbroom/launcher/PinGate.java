package io.github.adbroom.launcher;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.AsyncTask;
import android.text.InputType;
import android.util.Base64;
import android.widget.EditText;
import java.security.MessageDigest;
import java.security.SecureRandom;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;

/** Launcher-only parental gate; does not claim to restrict other launchers or ADB. */
final class PinGate {
    static SharedPreferences prefs(Context c) { return c.getSharedPreferences("parental",Context.MODE_PRIVATE); }
    static boolean enabled(Context c) { return prefs(c).contains("hash"); }
    static boolean locked(Context c,String pkg) { return enabled(c) && prefs(c).getBoolean("app:"+pkg,false); }
    static void admin(Activity a,Runnable action) { require(a,enabled(a) && prefs(a).getBoolean("protect",false),action); }
    static void require(Activity a,boolean needed,Runnable action) {
        if (!needed) { action.run(); return; }
        long until=prefs(a).getLong("until",0);
        if (until>System.currentTimeMillis()) { TvUi.message(a,"Çok fazla deneme. 30 saniye bekle.","Too many attempts. Wait 30 seconds."); return; }
        prompt(a,TvUi.t(a,"Ebeveyn PIN’i","Parental PIN"),pin -> {
            AsyncTask.THREAD_POOL_EXECUTOR.execute(() -> {
                boolean valid=false;
                try { valid=MessageDigest.isEqual(hash(pin,prefs(a).getString("salt","")),Base64.decode(prefs(a).getString("hash",""),Base64.NO_WRAP)); }
                catch(Exception ignored) {}
                final boolean accepted=valid;
                int failures=accepted ? 0 : prefs(a).getInt("failures",0)+1;
                prefs(a).edit().putInt("failures",failures>=5?0:failures).putLong("until",failures>=5?System.currentTimeMillis()+30000:0).commit();
                a.runOnUiThread(() -> { if (a.isFinishing() || a.isDestroyed()) return; if (accepted) action.run(); else TvUi.message(a,"PIN yanlış.","Incorrect PIN."); });
            });
        });
    }
    static void setup(Activity a) {
        require(a,enabled(a),() -> prompt(a,TvUi.t(a,"Yeni 4 haneli PIN","New 4-digit PIN"),pin ->
            prompt(a,TvUi.t(a,"PIN’i tekrar gir","Confirm PIN"),confirmation -> {
                if (!pin.equals(confirmation)) { TvUi.message(a,"PIN’ler eşleşmiyor.","PINs do not match."); return; }
                AsyncTask.THREAD_POOL_EXECUTOR.execute(() -> {
                    try {
                        byte[] salt=new byte[16]; new SecureRandom().nextBytes(salt); String encoded=Base64.encodeToString(salt,Base64.NO_WRAP);
                        prefs(a).edit().putString("salt",encoded).putString("hash",Base64.encodeToString(hash(pin,encoded),Base64.NO_WRAP)).putInt("failures",0).putLong("until",0).commit();
                        a.runOnUiThread(() -> { if (!a.isDestroyed()) { TvUi.message(a,"PIN kaydedildi.","PIN saved."); a.recreate(); } });
                    } catch(Exception error) { a.runOnUiThread(() -> TvUi.message(a,"PIN kaydedilemedi.","Could not save PIN.")); }
                });
            })));
    }
    static void remove(Activity a) { require(a,enabled(a),() -> { prefs(a).edit().clear().apply(); a.recreate(); }); }
    private static byte[] hash(String pin,String salt) throws Exception {
        PBEKeySpec spec=new PBEKeySpec(pin.toCharArray(),Base64.decode(salt,Base64.NO_WRAP),60000,256);
        try { return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA1").generateSecret(spec).getEncoded(); }
        finally { spec.clearPassword(); }
    }
    private static void prompt(Activity a,String title,TvUi.TextResult result) {
        // A native remote-friendly keypad avoids full-screen IMEs and never exposes PIN text.
        StringBuilder value=new StringBuilder();
        android.widget.LinearLayout content=new android.widget.LinearLayout(a);content.setOrientation(android.widget.LinearLayout.VERTICAL);
        content.setPadding(TvUi.dp(a,24),TvUi.dp(a,10),TvUi.dp(a,24),TvUi.dp(a,8));
        android.widget.TextView dots=TvUi.text(a,"○ ○ ○ ○",26,TvUi.TEXT);dots.setGravity(android.view.Gravity.CENTER);
        content.addView(dots,new android.widget.LinearLayout.LayoutParams(-1,TvUi.dp(a,42)));
        Runnable render=()->{StringBuilder text=new StringBuilder();for(int i=0;i<4;i++){if(i>0)text.append(' ');text.append(i<value.length()?"●":"○");}dots.setText(text);};
        android.widget.GridLayout keys=new android.widget.GridLayout(a);keys.setColumnCount(3);
        String[] labels={"1","2","3","4","5","6","7","8","9","⌫","0","×"};
        for(String label:labels){
            android.widget.Button key=TvUi.button(a,label);
            android.widget.GridLayout.LayoutParams params=new android.widget.GridLayout.LayoutParams();params.width=TvUi.dp(a,92);params.height=TvUi.dp(a,36);params.setMargins(TvUi.dp(a,3),TvUi.dp(a,3),TvUi.dp(a,3),TvUi.dp(a,3));keys.addView(key,params);
            key.setOnClickListener(v->{if("⌫".equals(label)){if(value.length()>0)value.deleteCharAt(value.length()-1);}else if("×".equals(label))value.setLength(0);else if(value.length()<4)value.append(label);render.run();});
        }
        content.addView(keys);
        AlertDialog dialog=new AlertDialog.Builder(a).setTitle(title).setView(content).setNegativeButton(android.R.string.cancel,null).setPositiveButton(android.R.string.ok,null).create();
        dialog.setOnKeyListener((d,key,event)->{
            int digit=key>=android.view.KeyEvent.KEYCODE_0&&key<=android.view.KeyEvent.KEYCODE_9?key-android.view.KeyEvent.KEYCODE_0
                :key>=android.view.KeyEvent.KEYCODE_NUMPAD_0&&key<=android.view.KeyEvent.KEYCODE_NUMPAD_9?key-android.view.KeyEvent.KEYCODE_NUMPAD_0:-1;
            if(digit>=0){if(event.getAction()==android.view.KeyEvent.ACTION_DOWN&&value.length()<4){value.append(digit);render.run();}return true;}
            if(key==android.view.KeyEvent.KEYCODE_DEL){if(event.getAction()==android.view.KeyEvent.ACTION_DOWN&&value.length()>0){value.deleteCharAt(value.length()-1);render.run();}return true;}
            return false;
        });
        dialog.setOnShowListener(d->dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(v->{
            if(value.length()!=4){TvUi.message(a,"4 hane gir.","Enter 4 digits.");return;}
            String pin=value.toString();value.setLength(0);dialog.dismiss();result.accept(pin);
        }));dialog.show();keys.getChildAt(0).requestFocus();
    }
}
