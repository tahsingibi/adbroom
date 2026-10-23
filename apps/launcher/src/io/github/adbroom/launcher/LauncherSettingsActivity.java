package io.github.adbroom.launcher;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.ActivityManager;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Bundle;
import android.os.StatFs;
import android.provider.Settings;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class LauncherSettingsActivity extends Activity {
    private final ExecutorService worker=Executors.newSingleThreadExecutor();
    private LinearLayout panel;
    private ScrollView scroll;
    private LauncherConfig config;
    private long revision;
    private int section;
    private String appliedLanguage;
    @Override protected void attachBaseContext(Context base){super.attachBaseContext(TvUi.localized(base));}
    private String t(String tr,String en){return TvUi.t(this,tr,en);}
    @Override public void onCreate(Bundle state){
        super.onCreate(state);
        section=state==null?0:state.getInt("section",0);
        appliedLanguage=LauncherConfig.read(this).value("language");
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_FULLSCREEN|View.SYSTEM_UI_FLAG_HIDE_NAVIGATION|View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
        LinearLayout root=new LinearLayout(this);root.setOrientation(LinearLayout.VERTICAL);root.setPadding(dp(40),dp(26),dp(40),dp(24));root.setBackgroundColor(TvUi.BG);
        root.addView(TvUi.text(this,t("adbroom  /  Ayarlar","adbroom  /  Settings"),26,TvUi.TEXT));
        LinearLayout body=new LinearLayout(this);LinearLayout.LayoutParams bodyParams=new LinearLayout.LayoutParams(-1,0,1);bodyParams.topMargin=dp(20);root.addView(body,bodyParams);
        LinearLayout nav=new LinearLayout(this);nav.setOrientation(LinearLayout.VERTICAL);body.addView(nav,new LinearLayout.LayoutParams(dp(190),-1));
        String[] titles={t("Ana ekran","Home screen"),t("Görünüm","Appearance"),t("Modüller","Modules"),t("Uygulamalar","Applications"),t("Ebeveyn kontrolü","Parental controls"),t("TV kısayolları","TV shortcuts"),t("Cihaz ve hakkında","Device & about")};
        for(int i=0;i<titles.length;i++) {final int index=i;Button button=TvUi.button(this,titles[i]);LinearLayout.LayoutParams params=new LinearLayout.LayoutParams(-1,dp(44));params.bottomMargin=dp(8);nav.addView(button,params);button.setOnClickListener(v->{section=index;scroll.scrollTo(0,0);reload();panel.requestFocus();});}
        scroll=new ScrollView(this);LinearLayout.LayoutParams scrollParams=new LinearLayout.LayoutParams(0,-1,1);scrollParams.setMarginStart(dp(22));body.addView(scroll,scrollParams);
        panel=new LinearLayout(this);panel.setOrientation(LinearLayout.VERTICAL);panel.setPadding(dp(20),dp(6),dp(12),dp(20));scroll.addView(panel);
        root.addView(TvUi.text(this,t("Yön tuşlarıyla gezin · OK ile seç · Geri ile ana ekrana dön","Navigate with arrows · OK to select · Back to home"),11,TvUi.MUTED));
        setContentView(root);reload();nav.getChildAt(section).requestFocus();
    }
    @Override protected void onSaveInstanceState(Bundle state){state.putInt("section",section);super.onSaveInstanceState(state);}
    void setSaving(){for(int i=0;i<panel.getChildCount();i++)panel.getChildAt(i).setEnabled(false);}
    void reload(){
        if(isDestroyed())return;
        synchronized(OrderStore.LOCK){config=LauncherConfig.read(this);revision=OrderStore.revision(this);}
        if(!config.value("language").equals(appliedLanguage)){recreate();return;}
        View oldFocus=getCurrentFocus();String focusLabel=oldFocus instanceof Button?((Button)oldFocus).getText().toString().split("\n")[0]:"";
        int oldY=scroll.getScrollY();panel.removeAllViews();
        switch(section){
            case 0:
                heading(t("Ana ekran","Home screen"));
                choice(t("Düzen","Layout"),"layout",new String[]{"grid","row"},new String[]{t("Izgara","Grid"),t("Yatay sıra","Horizontal row")});
                row(t("Izgara sütunları","Grid columns"),Integer.toString(config.json.optInt("columns")),()->new AlertDialog.Builder(this).setTitle(t("Sütun sayısı","Column count")).setItems(new String[]{"4","5","6","7","8"},(d,w)->put("columns",w+4)).show());
                toggle(t("Son odaklanan uygulamayı hatırla","Remember focused app"),"rememberFocus");
                toggle(t("Telefon / sideload uygulamalarını göster","Show phone / sideloaded apps"),"showSideloaded");
                row(t("Profil adı","Profile name"),config.value("profileName"),()->TvUi.input(this,t("Profil adı","Profile name"),config.value("profileName"),40,v->put("profileName",v)));
                choice(t("Dil","Language"),"language",new String[]{"system","tr","en"},new String[]{t("TV dili","TV language"),"Türkçe","English"});
                row(t("Home tuşu ADBroom’u açsın","Home button opens ADBroom"),t("İsteğe bağlı erişilebilirlik hizmeti","Optional accessibility service"),()->new AlertDialog.Builder(this).setTitle(t("Home tuşu yönlendirme","Home button routing")).setMessage(t("Bu seçenek yalnızca sen Android erişilebilirlik ayarlarından ADBroom Home hizmetini açarsan çalışır. Hizmet Home tuşunu ve diğer ana ekranların açılmasını izler; ekran içeriğini okuyamaz. Android 13+ yan yükleme kısıtlamaları nedeniyle bazı TV’lerde açılamayabilir.","This works only after you enable ADBroom Home in Android accessibility settings. It observes the Home key and other launcher windows; it cannot retrieve screen contents. Android 13+ sideload restrictions may prevent enabling it on some TVs.")).setNegativeButton(android.R.string.cancel,null).setPositiveButton(t("Erişilebilirlik ayarlarını aç","Open accessibility settings"),(d,w)->TvUi.system(this,Settings.ACTION_ACCESSIBILITY_SETTINGS)).show());
                row(t("Varsayılan ana ekran","Default home app"),t("TV’nin seçim ekranını aç","Open TV home picker"),()->TvUi.system(this,Settings.ACTION_HOME_SETTINGS));break;
            case 1:
                heading(t("Görünüm","Appearance"));
                choice(t("Arka plan","Background"),"theme",new String[]{"midnight","forest","warm"},new String[]{t("Gece","Midnight"),t("Orman","Forest"),t("Sıcak","Warm")});
                choice(t("Vurgu rengi","Accent color"),"accent",new String[]{"sage","blue","amber"},new String[]{t("Adaçayı","Sage"),t("Mavi","Blue"),t("Kehribar","Amber")});
                choice(t("Uygulama kartı","App card"),"cardStyle",new String[]{"icon","banner"},new String[]{t("İkon","Icon"),t("TV görseli","TV banner")});
                toggle(t("Uygulama adlarını göster","Show app names"),"showLabels");
                row(t("Fotoğrafı duvar kâğıdı yap","Use a picture as wallpaper"),t("Sistem dosya seçicisi · Depolama izni istemez","System file picker · No storage permission"),()->{
                    try{startActivityForResult(new Intent(Intent.ACTION_OPEN_DOCUMENT).setType("image/*").addCategory(Intent.CATEGORY_OPENABLE),42);}catch(RuntimeException e){TvUi.message(this,"Bu TV’de dosya seçici yok.","No file picker is available on this TV.");}
                });
                row(t("Fotoğrafı kaldır","Remove custom wallpaper"),"",()->{worker.execute(()->{new File(getFilesDir(),"wallpaper.jpg").delete();getContentResolver().notifyChange(OrderStore.URI,null);runOnUiThread(()->TvUi.message(this,"Duvar kâğıdı kaldırıldı.","Wallpaper removed."));});});
                note(t("Odak geçişleri anlıktır. Duvar kâğıdı bir kez küçültülerek yüklenir.","Focus changes are immediate. Wallpaper is downsampled and loaded once."));break;
            case 2:
                heading(t("Ana ekran modülleri","Home modules"));
                toggle(t("Favori rafı","Favorites shelf"),"showFavorites");toggle(t("Saat","Clock"),"showClock");toggle(t("24 saat biçimi","24-hour clock"),"use24Hour");toggle(t("Tarih","Date"),"showDate");toggle(t("Ağ durumu","Network status"),"showNetwork");toggle(t("Canlı TV ve HDMI girişleri","Live TV and HDMI inputs"),"showInputs");toggle(t("Bağlı olmayan HDMI girişlerini gizle","Hide disconnected HDMI inputs"),"hideDisconnectedInputs");toggle(t("Son medya","Last media"),"showMedia");
                row(t("Medya geçmişini temizle","Clear media history"),t("Yalnızca son başlık ve kaynak uygulama TV’de saklanır","Only the last title and source app are stored on the TV"),()->{getSharedPreferences("media-history",MODE_PRIVATE).edit().clear().apply();TvUi.message(this,"Medya geçmişi temizlendi.","Media history cleared.");});
                row(t("Medya erişimi","Media access"),t("İsteğe bağlı bildirim erişimi; sistem oturumundan başlık ve ilerleme","Optional notification access; title and progress from media sessions"),()->new AlertDialog.Builder(this).setTitle(t("Medya erişimi","Media access")).setMessage(t("Son medya modülü için Android bildirim erişimini kendin açabilirsin. ADBroom bildirim metinlerini kaydetmez; medya oturumlarını yalnızca ana ekran görünürken okur.","You can enable Android notification access for the media module. ADBroom does not store notification text; it reads media sessions only while Home is visible.")).setNegativeButton(android.R.string.cancel,null).setPositiveButton(t("Sistem ayarını aç","Open system settings"),(d,w)->TvUi.system(this,Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)).show());break;
            case 3:
                heading(t("Uygulamaları yönet","Manage applications"));note(t("Favoriler, adlar, klasörler, gizli uygulamalar ve PIN kilitleri. Gizlemek uygulamayı TV’den silmez.","Favorites, names, folders, hidden apps and PIN locks. Hiding an app does not uninstall it."));
                worker.execute(()->{List<AppCatalog.Entry> apps=AppCatalog.load(this);runOnUiThread(()->{if(isDestroyed()||section!=3)return;for(AppCatalog.Entry entry:apps){String detail=entry.pkg+(config.includes("hidden",entry.pkg)?t(" · Gizli"," · Hidden"):"")+(config.includes("favorites",entry.pkg)?" · ★":"");row(config.label(entry.pkg,entry.label),detail,()->AppActions.show(this,entry,worker,null));}});});break;
            case 4:
                heading(t("Ebeveyn kontrolü","Parental controls"));
                row(PinGate.enabled(this)?t("PIN’i değiştir","Change PIN"):t("4 haneli PIN oluştur","Set 4-digit PIN"),"",()->PinGate.setup(this));
                if(PinGate.enabled(this)){
                    row(t("Ayarları ve düzenlemeyi koru","Protect settings and editing"),PinGate.prefs(this).getBoolean("protect",false)?t("Açık","On"):t("Kapalı","Off"),()->PinGate.require(this,true,()->{PinGate.prefs(this).edit().putBoolean("protect",!PinGate.prefs(this).getBoolean("protect",false)).apply();reload();}));
                    row(t("PIN’i ve tüm kilitleri kaldır","Remove PIN and all locks"),"",()->PinGate.remove(this));
                }
                note(t("Uygulamaları Uygulamalar bölümünden PIN ile kilitle. Bu launcher içi bir kontroldür; TV’nin diğer girişlerini, sistem ayarlarını veya ADB’yi kilitlemez.","Lock apps from Applications. This is a launcher-level control; it does not lock other TV entry points, system settings or ADB."));break;
            case 5:
                heading(t("TV kısayolları","TV shortcuts"));
                String[] labels={t("Ağ ve Wi-Fi","Network & Wi-Fi"),t("Görüntü","Display"),t("Ses","Sound"),"Bluetooth",t("Uygulamalar","Applications"),t("Girişler","Inputs"),t("TV’nin tüm ayarları","All TV settings")};
                String[] actions={Settings.ACTION_WIFI_SETTINGS,Settings.ACTION_DISPLAY_SETTINGS,Settings.ACTION_SOUND_SETTINGS,Settings.ACTION_BLUETOOTH_SETTINGS,Settings.ACTION_MANAGE_APPLICATIONS_SETTINGS,"android.settings.TV_INPUT_SETTINGS",Settings.ACTION_SETTINGS};
                for(int i=0;i<labels.length;i++){final String action=actions[i];row(labels[i],"",()->TvUi.system(this,action));}break;
            case 6:
                heading(t("Cihaz ve hakkında","Device & about"));
                ActivityManager.MemoryInfo memory=new ActivityManager.MemoryInfo();((ActivityManager)getSystemService(ACTIVITY_SERVICE)).getMemoryInfo(memory);StatFs disk=new StatFs(getFilesDir().getPath());
                note(android.os.Build.MANUFACTURER+" "+android.os.Build.MODEL+"\nAndroid "+android.os.Build.VERSION.RELEASE+" · API "+android.os.Build.VERSION.SDK_INT+"\nRAM: "+mb(memory.availMem)+" / "+mb(memory.totalMem)+" MB\n"+t("Boş alan: ","Free storage: ")+mb(disk.getAvailableBytes())+" / "+mb(disk.getTotalBytes())+" MB\nADBroom Launcher 1.2.1");
                row(t("Görünüm ve uygulama tercihlerini sıfırla","Reset appearance and app preferences"),t("Sıralama ve ebeveyn PIN’i korunur","App order and parental PIN are preserved"),()->new AlertDialog.Builder(this).setTitle(t("Tercihler sıfırlansın mı?","Reset preferences?")).setNegativeButton(android.R.string.cancel,null).setPositiveButton(android.R.string.ok,(d,w)->{try{AppActions.save(this,worker,new LauncherConfig(new org.json.JSONObject()),revision);}catch(Exception ignored){}}).show());
                note("Tahsin Sungur\ntahsingibi\nsungur.dev");
                note(t("Açık kaynak · Native Android · Reklamsız\nLisans bilgileri projenin LICENSE dosyasında.","Open source · Native Android · Ad-free\nSee the project LICENSE for licensing."));break;
        }
        scroll.post(()->{
            for(int i=0;i<panel.getChildCount();i++){
                View child=panel.getChildAt(i);
                if(child instanceof Button && !focusLabel.isEmpty() && ((Button)child).getText().toString().split("\n")[0].equals(focusLabel)){child.requestFocus();break;}
            }
            scroll.scrollTo(0,oldY);
        });
    }
    private int dp(int v){return TvUi.dp(this,v);}
    private long mb(long value){return value/(1024*1024);}
    private void heading(String value){panel.addView(TvUi.text(this,value,22,TvUi.TEXT));}
    private void note(String value){android.widget.TextView text=TvUi.text(this,value,13,TvUi.MUTED);text.setPadding(0,dp(10),0,dp(16));panel.addView(text);}
    private void row(String title,String value,Runnable action){Button button=TvUi.button(this,title+(value.isEmpty()?"":"\n"+value));button.setGravity(Gravity.CENTER_VERTICAL|Gravity.START);button.setSingleLine(false);LinearLayout.LayoutParams params=new LinearLayout.LayoutParams(-1,dp(value.isEmpty()?48:66));params.topMargin=dp(10);panel.addView(button,params);button.setOnClickListener(v->action.run());}
    private void toggle(String title,String key){row(title,config.flag(key)?t("Açık","On"):t("Kapalı","Off"),()->put(key,!config.flag(key)));}
    private void choice(String title,String key,String[] values,String[] names){int current=java.util.Arrays.asList(values).indexOf(config.value(key));row(title,names[Math.max(0,current)],()->new AlertDialog.Builder(this).setTitle(title).setSingleChoiceItems(names,current,(d,w)->{d.dismiss();put(key,values[w]);}).setNegativeButton(android.R.string.cancel,null).show());}
    private void put(String key,Object value){config.set(key,value);AppActions.save(this,worker,config,revision);}
    @Override protected void onActivityResult(int request,int result,Intent data){
        super.onActivityResult(request,result,data);if(request!=42||result!=RESULT_OK||data==null||data.getData()==null)return;Uri uri=data.getData();
        worker.execute(()->{
            try{
                BitmapFactory.Options bounds=new BitmapFactory.Options();bounds.inJustDecodeBounds=true;try(InputStream input=getContentResolver().openInputStream(uri)){BitmapFactory.decodeStream(input,null,bounds);}
                if(bounds.outWidth<=0||bounds.outHeight<=0)throw new IllegalArgumentException("Invalid image");
                BitmapFactory.Options options=new BitmapFactory.Options();options.inSampleSize=1;while(bounds.outWidth/options.inSampleSize>1920||bounds.outHeight/options.inSampleSize>1080)options.inSampleSize*=2;
                Bitmap bitmap;try(InputStream input=getContentResolver().openInputStream(uri)){bitmap=BitmapFactory.decodeStream(input,null,options);}if(bitmap==null)throw new IllegalArgumentException("Invalid image");
                File temp=new File(getFilesDir(),"wallpaper-new.jpg");try(FileOutputStream output=new FileOutputStream(temp)){if(!bitmap.compress(Bitmap.CompressFormat.JPEG,88,output))throw new java.io.IOException();}bitmap.recycle();
                if(!temp.renameTo(new File(getFilesDir(),"wallpaper.jpg")))throw new java.io.IOException();getContentResolver().notifyChange(OrderStore.URI,null);runOnUiThread(()->TvUi.message(this,"Duvar kâğıdı kaydedildi.","Wallpaper saved."));
            }catch(Exception error){runOnUiThread(()->TvUi.message(this,"Görsel yüklenemedi.","Could not load picture."));}
        });
    }
    @Override protected void onDestroy(){worker.shutdown();super.onDestroy();}
}
