package io.github.adbroom.launcher;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.media.MediaMetadata;
import android.media.session.MediaController;
import android.media.session.MediaSessionManager;
import android.media.session.PlaybackState;
import android.media.tv.TvInputInfo;
import android.media.tv.TvInputManager;
import android.media.tv.TvContract;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkInfo;
import android.net.NetworkRequest;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.util.List;

/** Event driven modules, registered only while the home activity is visible. */
final class HomeModules {
    private final Activity activity;
    private final TextView networkLabel;
    private final LinearLayout inputs;
    private final Button media;
    private final Handler main=new Handler(Looper.getMainLooper());
    private LauncherConfig config;
    private ConnectivityManager connectivity;
    private TvInputManager tv;
    private MediaSessionManager sessions;
    private MediaController controller;
    private boolean networkRegistered,tvRegistered,mediaRegistered;
    private final ConnectivityManager.NetworkCallback networkCallback=new ConnectivityManager.NetworkCallback(){
        @Override public void onAvailable(Network network){main.post(()->network());}
        @Override public void onLost(Network network){main.post(()->network());}
        @Override public void onCapabilitiesChanged(Network network,android.net.NetworkCapabilities capabilities){main.post(()->network());}
    };
    private final TvInputManager.TvInputCallback tvCallback=new TvInputManager.TvInputCallback(){
        @Override public void onInputStateChanged(String id,int state){renderInputs();}
        @Override public void onInputAdded(String id){renderInputs();}
        @Override public void onInputRemoved(String id){renderInputs();}
    };
    private final MediaSessionManager.OnActiveSessionsChangedListener sessionListener=controllers->selectMedia(controllers);
    private final MediaController.Callback mediaCallback=new MediaController.Callback(){
        @Override public void onMetadataChanged(MediaMetadata metadata){renderMedia();}
        @Override public void onPlaybackStateChanged(PlaybackState state){renderMedia();}
        @Override public void onSessionDestroyed(){selectMedia(java.util.Collections.emptyList());}
    };
    HomeModules(Activity a,TextView n,LinearLayout i,Button m){activity=a;networkLabel=n;inputs=i;media=m;}
    void start(LauncherConfig config){
        stop();this.config=config;
        connectivity=(ConnectivityManager)activity.getSystemService(Context.CONNECTIVITY_SERVICE);
        tv=(TvInputManager)activity.getSystemService(Context.TV_INPUT_SERVICE);
        network();renderInputs();
        if(config.flag("showNetwork")&&connectivity!=null)try{connectivity.registerNetworkCallback(new NetworkRequest.Builder().build(),networkCallback);networkRegistered=true;}catch(RuntimeException ignored){}
        if(config.flag("showInputs")&&tv!=null)try{tv.registerCallback(tvCallback,main);tvRegistered=true;}catch(RuntimeException ignored){}
        media.setVisibility(View.GONE);
        if(config.flag("showMedia")){
            sessions=(MediaSessionManager)activity.getSystemService(Context.MEDIA_SESSION_SERVICE);
            try{ComponentName listener=new ComponentName(activity,MediaAccessService.class);sessions.addOnActiveSessionsChangedListener(sessionListener,listener,main);mediaRegistered=true;selectMedia(sessions.getActiveSessions(listener));}
            catch(RuntimeException error){media.setVisibility(View.VISIBLE);media.setText(TvUi.t(activity,"Son medya · erişimi aç","Last media · enable access"));media.setOnClickListener(v->TvUi.system(activity,android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS));}
        }
    }
    void stop(){
        if(networkRegistered)try{connectivity.unregisterNetworkCallback(networkCallback);}catch(RuntimeException ignored){}
        if(tvRegistered)try{tv.unregisterCallback(tvCallback);}catch(RuntimeException ignored){}
        if(mediaRegistered)try{sessions.removeOnActiveSessionsChangedListener(sessionListener);}catch(RuntimeException ignored){}
        if(controller!=null)controller.unregisterCallback(mediaCallback);
        controller=null;networkRegistered=tvRegistered=mediaRegistered=false;main.removeCallbacksAndMessages(null);
    }
    private void network(){
        if(config==null)return;networkLabel.setVisibility(config.flag("showNetwork")?View.VISIBLE:View.GONE);
        String value=TvUi.t(activity,"Çevrimdışı","Offline");
        try{NetworkInfo info=connectivity==null?null:connectivity.getActiveNetworkInfo();if(info!=null&&info.isConnected())value=info.getType()==ConnectivityManager.TYPE_WIFI?"Wi-Fi":info.getType()==ConnectivityManager.TYPE_ETHERNET?"Ethernet":TvUi.t(activity,"Bağlı","Connected");}catch(RuntimeException ignored){}
        networkLabel.setText(value);
    }
    private void renderInputs(){
        inputs.removeAllViews();if(config==null||!config.flag("showInputs")||tv==null)return;
        try{for(TvInputInfo info:tv.getTvInputList()){
            if(info.isHidden(activity))continue;
            int state=tv.getInputState(info.getId());
            if(info.isPassthroughInput()&&config.flag("hideDisconnectedInputs")&&state==TvInputManager.INPUT_STATE_DISCONNECTED)continue;
            CharSequence custom=info.loadCustomLabel(activity);String label=custom==null?info.loadLabel(activity).toString():custom.toString();
            Button button=TvUi.button(activity,(info.isPassthroughInput()?"↗ ":"◉ ")+label+(state==TvInputManager.INPUT_STATE_DISCONNECTED?TvUi.t(activity," · bağlı değil"," · disconnected"):state==TvInputManager.INPUT_STATE_CONNECTED_STANDBY?TvUi.t(activity," · beklemede"," · standby"):""));
            button.setOnClickListener(v->{
                try{activity.startActivity(new Intent(Intent.ACTION_VIEW,info.isPassthroughInput()?TvContract.buildChannelUriForPassthroughInput(info.getId()):TvContract.buildChannelsUriForInput(info.getId())));}
                catch(RuntimeException error){TvUi.system(activity,"android.settings.TV_INPUT_SETTINGS");}
            });
            LinearLayout.LayoutParams params=new LinearLayout.LayoutParams(-2,TvUi.dp(activity,36));params.setMarginEnd(TvUi.dp(activity,10));inputs.addView(button,params);
        }}catch(RuntimeException ignored){}
    }
    private void selectMedia(List<MediaController> controllers){
        if(controller!=null)controller.unregisterCallback(mediaCallback);controller=controllers.isEmpty()?null:controllers.get(0);
        if(controller!=null)controller.registerCallback(mediaCallback,main);renderMedia();
    }
    private void renderMedia(){
        if(config==null||!config.flag("showMedia"))return;
        MediaMetadata metadata=controller==null?null:controller.getMetadata();
        String title=metadata==null?"":metadata.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE);
        if(title==null||title.isEmpty())title=metadata==null?"":metadata.getString(MediaMetadata.METADATA_KEY_TITLE);
        if(title!=null&&!title.isEmpty()){
            activity.getSharedPreferences("media-history",Context.MODE_PRIVATE).edit().putString("title",title).putString("package",controller.getPackageName()).apply();
        }else title=activity.getSharedPreferences("media-history",Context.MODE_PRIVATE).getString("title","");
        media.setVisibility(title.isEmpty()?View.GONE:View.VISIBLE);
        String progress="";PlaybackState state=controller==null?null:controller.getPlaybackState();
        if(state!=null&&state.getPosition()>0)progress=" · "+(state.getPosition()/60000)+":"+String.format(java.util.Locale.ROOT,"%02d",(state.getPosition()/1000)%60);
        media.setText("▶ "+title+progress);
        media.setOnClickListener(v->{
            String pkg=controller==null?activity.getSharedPreferences("media-history",Context.MODE_PRIVATE).getString("package",""):controller.getPackageName();
            PinGate.require(activity,PinGate.locked(activity,pkg),()->{
                try{PendingIntent intent=controller==null?null:controller.getSessionActivity();if(intent!=null)intent.send();else{Intent launch=activity.getPackageManager().getLeanbackLaunchIntentForPackage(pkg);if(launch==null)launch=activity.getPackageManager().getLaunchIntentForPackage(pkg);if(launch!=null)activity.startActivity(launch);}}
                catch(Exception error){TvUi.message(activity,"Medya uygulaması açılamadı.","Could not open the media app.");}
            });
        });
    }
}
