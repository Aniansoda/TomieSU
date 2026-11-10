package io.tomiesu.manager.magica;

import android.app.ZygotePreload;
import android.content.pm.ApplicationInfo;
import android.util.Log;

import androidx.annotation.NonNull;

import java.io.File;

public class AppZygotePreload implements ZygotePreload {
    public static final String TAG = "KernelSUMagica";

    private static native void forkDontCareAndExecTsud(String tsudPath, String packageName);

    @Override
    public void doPreload(@NonNull ApplicationInfo appInfo) {
        File f = new File(appInfo.nativeLibraryDir, "libtsud.so");
        // The daemon is staged per ABI. When this APK has no daemon for the
        // device ABI, forking would exec a path that does not exist and the app
        // zygote would keep a broken child around.
        if (!f.isFile()) {
            Log.w(TAG, "no tsud daemon for this ABI: " + f.getAbsolutePath());
            return;
        }
        try {
            System.loadLibrary("tomiesu");
            Log.d(TAG, "executing magica ...");
            forkDontCareAndExecTsud(f.getAbsolutePath(), appInfo.packageName);
        } catch (Throwable t) {
            Log.e(TAG, "failed to late load", t);
        }
    }
}
