package io.github.adbroom.launcher;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.net.Uri;
import android.provider.Settings;
import java.util.concurrent.Executor;

final class AppActions {
    static void show(Activity activity,AppCatalog.Entry entry,Executor worker,Runnable arrange) {
        PinGate.admin(activity,() -> {
            final LauncherConfig config;
            final long revision;
            synchronized(OrderStore.LOCK) { config=LauncherConfig.read(activity); revision=OrderStore.revision(activity); }
            String[] options={
                TvUi.t(activity,"Taşı / sırala","Move / rearrange"),
                config.includes("favorites",entry.pkg)?TvUi.t(activity,"Favorilerden çıkar","Remove favorite"):TvUi.t(activity,"Favorilere ekle","Add favorite"),
                TvUi.t(activity,"Yeniden adlandır","Rename"),
                TvUi.t(activity,"Klasör / koleksiyon","Folder / collection"),
                config.includes("hidden",entry.pkg)?TvUi.t(activity,"Ana ekranda göster","Show on home"):TvUi.t(activity,"Ana ekrandan gizle","Hide from home"),
                PinGate.locked(activity,entry.pkg)?TvUi.t(activity,"PIN kilidini kaldır","Remove PIN lock"):TvUi.t(activity,"PIN ile kilitle","Lock with PIN"),
                TvUi.t(activity,"Uygulama bilgisi","App info")};
            new AlertDialog.Builder(activity).setTitle(config.label(entry.pkg,entry.label)).setItems(options,(d,which)-> {
                switch(which) {
                    case 0: if(arrange!=null) arrange.run(); else TvUi.message(activity,"Ana ekranda Menü ile sırala.","Use Menu on the home screen to rearrange."); break;
                    case 1: config.toggleApp("favorites",entry.pkg); save(activity,worker,config,revision); break;
                    case 2: TvUi.input(activity,TvUi.t(activity,"Ad (boş bırakırsan özgün ad)","Name (empty restores original)"),config.json.optJSONObject("labels").optString(entry.pkg,""),60,value->{config.setAppText("labels",entry.pkg,value);save(activity,worker,config,revision);}); break;
                    case 3: TvUi.input(activity,TvUi.t(activity,"Klasör adı (boş: klasörsüz)","Folder name (empty: no folder)"),config.group(entry.pkg),30,value->{config.setAppText("groups",entry.pkg,value);save(activity,worker,config,revision);}); break;
                    case 4: config.toggleApp("hidden",entry.pkg); save(activity,worker,config,revision); break;
                    case 5:
                        if(!PinGate.enabled(activity)) { PinGate.setup(activity); break; }
                        PinGate.require(activity,true,()->{PinGate.prefs(activity).edit().putBoolean("app:"+entry.pkg,!PinGate.locked(activity,entry.pkg)).apply();TvUi.message(activity,"Uygulama kilidi güncellendi.","App lock updated.");}); break;
                    case 6: try { activity.startActivity(new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,Uri.parse("package:"+entry.pkg))); } catch(RuntimeException error){ TvUi.system(activity,Settings.ACTION_MANAGE_APPLICATIONS_SETTINGS); } break;
                }
            }).show();
        });
    }
    static void save(Activity activity,Executor worker,LauncherConfig config,long revision) {
        final LauncherConfig snapshot;
        try { snapshot=new LauncherConfig(new org.json.JSONObject(config.json.toString())); }
        catch (Exception error) { TvUi.message(activity,"Ayarlar geçersiz.","Invalid settings."); return; }
        if(activity instanceof LauncherSettingsActivity)((LauncherSettingsActivity)activity).setSaving();
        worker.execute(()->{
            String status=OrderStore.saveProfile(activity,null,snapshot,revision);
            activity.runOnUiThread(()->{
                if(activity.isDestroyed()) return;
                if(!"ok".equals(status)) TvUi.message(activity,"Ayarlar değişti veya kaydedilemedi. Yeniden dene.","Settings changed or could not be saved. Try again.");
                if(activity instanceof LauncherSettingsActivity) ((LauncherSettingsActivity)activity).reload();
            });
        });
    }
}
