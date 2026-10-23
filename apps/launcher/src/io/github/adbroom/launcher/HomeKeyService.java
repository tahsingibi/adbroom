package io.github.adbroom.launcher;

import android.accessibilityservice.AccessibilityService;
import android.content.Intent;
import android.content.pm.ResolveInfo;
import android.os.SystemClock;
import android.view.KeyEvent;
import android.view.accessibility.AccessibilityEvent;
import java.util.HashSet;
import java.util.Set;

/** Optional, user-enabled HOME routing. Does not request or retrieve window contents. */
public final class HomeKeyService extends AccessibilityService {
    private final Set<String> otherHomes=new HashSet<>();
    private long lastLaunch;
    @Override protected void onServiceConnected(){
        otherHomes.clear();
        Intent home=new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME);
        for(ResolveInfo info:getPackageManager().queryIntentActivities(home,0))
            if(!getPackageName().equals(info.activityInfo.packageName))otherHomes.add(new android.content.ComponentName(info.activityInfo.packageName,info.activityInfo.name).flattenToString());
    }
    @Override protected boolean onKeyEvent(KeyEvent event){
        if(event.getKeyCode()!=KeyEvent.KEYCODE_HOME)return false;
        if(event.getAction()==KeyEvent.ACTION_UP)openHome();
        return true;
    }
    @Override public void onAccessibilityEvent(AccessibilityEvent event){
        // Only the window's package name is inspected; no text, view tree, or content is read.
        if(event.getEventType()!=AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED || event.getPackageName()==null || event.getClassName()==null)return;
        String pkg=event.getPackageName().toString(), name=event.getClassName().toString();
        if(name.startsWith("."))name=pkg+name;
        // Match the activity too: the Settings package can also contain Android's fallback home.
        // Routing every window in that package would incorrectly close ordinary TV settings.
        if(otherHomes.contains(new android.content.ComponentName(pkg,name).flattenToString()))openHome();
    }
    private void openHome(){
        long now=SystemClock.elapsedRealtime();if(now-lastLaunch<700)return;lastLaunch=now;
        try{startActivity(new Intent(this,HomeActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_CLEAR_TOP));}
        catch(RuntimeException ignored){}
    }
    @Override public void onInterrupt(){}
}
