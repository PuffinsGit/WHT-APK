#!/usr/bin/env bash
set -euo pipefail

JAVA_DIR="android/app/src/main/java/com/workedhourstracker/app"
MANIFEST="android/app/src/main/AndroidManifest.xml"

if [[ ! -d "$JAVA_DIR" || ! -f "$MANIFEST" ]]; then
  echo "Android project has not been generated. Run npx cap add android first."
  exit 1
fi

# GallerySaver refreshes the WHT widgets after each save, so generate their
# Java providers first. This guarantees they exist before Java compilation.
if [[ ! -f "scripts/apply-clock-widget.sh" ]]; then
  echo "Missing scripts/apply-clock-widget.sh; widget providers cannot be generated."
  exit 1
fi
bash ./scripts/apply-clock-widget.sh

python - <<'PY'
from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text()
permission = '    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />\n'
if "android.permission.WRITE_EXTERNAL_STORAGE" not in text:
    start = text.find("<manifest")
    end = text.find(">", start)
    text = text[:end + 1] + "\n" + permission + text[end + 1:]
notification_permission = '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n'
if "android.permission.POST_NOTIFICATIONS" not in text:
    start = text.find("<manifest")
    end = text.find(">", start)
    text = text[:end + 1] + "\n" + notification_permission + text[end + 1:]
promoted_permission = '    <uses-permission android:name="android.permission.POST_PROMOTED_NOTIFICATIONS" />\n'
if "android.permission.POST_PROMOTED_NOTIFICATIONS" not in text:
    start = text.find("<manifest")
    end = text.find(">", start)
    text = text[:end + 1] + "\n" + promoted_permission + text[end + 1:]
manifest.write_text(text)
PY

cat > "$JAVA_DIR/MainActivity.java" <<'JAVA'
package com.workedhourstracker.app;

import android.os.Bundle;
import android.os.Build;
import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        registerPlugin(GallerySaverPlugin.class);
        super.onCreate(savedInstanceState);
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 2450);
        }
        openRequestedScreen(getIntent());
    }

    @Override protected void onNewIntent(Intent intent) { super.onNewIntent(intent); setIntent(intent); openRequestedScreen(intent); }
    @Override public void onResume() {
        super.onResume();
        refreshWidgets();
    }
    @Override public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        refreshWidgets();
    }
    private void refreshWidgets() {
        ClockWidgetProvider.refreshAll(this);
        NextShiftWidgetProvider.refreshAll(this);
        ShiftProgressWidgetProvider.refreshAll(this);
    }
    private void openRequestedScreen(Intent intent) {
        if (intent == null || !"schedule".equals(intent.getStringExtra("wht_open_screen"))) return;
        intent.removeExtra("wht_open_screen");
        getBridge().getWebView().postDelayed(() -> getBridge().getWebView().evaluateJavascript("if(typeof showScheduleScreen==='function'){if(typeof closeSidebar==='function')closeSidebar();showScheduleScreen();}", null), 900);
    }
}
JAVA

cat > "$JAVA_DIR/GallerySaverPlugin.java" <<'JAVA'
package com.workedhourstracker.app;

import android.Manifest;
import android.content.ClipData;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Intent;
import android.database.Cursor;
import android.media.MediaScannerConnection;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Base64;

import com.getcapacitor.JSObject;
import com.getcapacitor.PermissionState;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.annotation.Permission;
import com.getcapacitor.annotation.PermissionCallback;

import androidx.core.content.FileProvider;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;

@CapacitorPlugin(
    name = "GallerySaver",
    permissions = @Permission(
        alias = "storage",
        strings = Manifest.permission.WRITE_EXTERNAL_STORAGE
    )
)
public class GallerySaverPlugin extends Plugin {
    private static final String WIDGET_PREFS = "wht_device_save";
    private static final String WIDGET_DATA = "app_data";
    private static final String SAVE_NAME = "wht-save.json";

    @PluginMethod
    public void playClockTone(PluginCall call) {
        WhtClockSound.play(getContext());
        call.resolve();
    }
    private static final String SAVE_MIME = "application/json";
    private static final String SAVE_FOLDER = "Download/WHT/";

    @PluginMethod
    public void saveAppData(PluginCall call) {
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P && getPermissionState("storage") != PermissionState.GRANTED) {
            requestPermissionForAlias("storage", call, "storagePermissionResult");
            return;
        }
        saveAppDataNow(call);
    }

    private synchronized void saveAppDataNow(PluginCall call) {
        String data = call.getString("data");
        if (data == null) {
            call.reject("Save data was missing.");
            return;
        }

        try {
            // Commit the authoritative app/widget state first. The public backup
            // is secondary and must never block live widget updates.
            boolean committed = getContext().getSharedPreferences(WIDGET_PREFS, 0)
                .edit().putString(WIDGET_DATA, data).commit();
            if (!committed) throw new Exception("Android could not commit app data.");
            ClockWidgetProvider.refreshAll(getContext());
            NextShiftWidgetProvider.refreshAll(getContext());
            ShiftProgressWidgetProvider.refreshAll(getContext());
            WhtClockNotification.sync(getContext(), new org.json.JSONObject(data));
            JSObject result = new JSObject();
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) savePublicDocument(data);
                else saveLegacyDocument(data);
                result.put("backupSaved", true);
            } catch (Exception backupError) {
                result.put("backupSaved", false);
            }
            call.resolve(result);
        } catch (Exception error) {
            call.reject("Could not write the device backup: " + error.getMessage(), error);
        }
    }

    @PluginMethod
    public synchronized void loadAppData(PluginCall call) {
        JSObject result = new JSObject();
        try {
            String data = getContext().getSharedPreferences(WIDGET_PREFS, 0).getString(WIDGET_DATA, "");
            if (data == null || data.isEmpty()) {
                data = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ? loadPublicDocument() : loadLegacyDocument();
                if (data != null && !data.isEmpty()) getContext().getSharedPreferences(WIDGET_PREFS, 0).edit().putString(WIDGET_DATA, data).apply();
            }
            WhtClockNotification.sync(getContext(), new org.json.JSONObject(data == null || data.isEmpty() ? "{}" : data));
            result.put("data", data == null ? "" : data);
            call.resolve(result);
        } catch (Exception error) {
            call.reject("Could not read the device backup: " + error.getMessage(), error);
        }
    }

    private void savePublicDocument(String data) throws Exception {
        ContentResolver resolver = getContext().getContentResolver();
        Uri existing = findPublicDocument(resolver);
        if (existing != null) {
            try (OutputStream stream = resolver.openOutputStream(existing, "wt")) {
                if (stream == null) throw new Exception("Android could not open the backup file.");
                stream.write(data.getBytes(StandardCharsets.UTF_8));
            }
            return;
        }

        ContentValues values = new ContentValues();
        values.put(MediaStore.Downloads.DISPLAY_NAME, SAVE_NAME);
        values.put(MediaStore.Downloads.MIME_TYPE, SAVE_MIME);
        values.put(MediaStore.Downloads.RELATIVE_PATH, SAVE_FOLDER);
        Uri uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values);
        if (uri == null) throw new Exception("Android could not create the backup file.");
        try (OutputStream stream = resolver.openOutputStream(uri)) {
            if (stream == null) throw new Exception("Android could not open the backup file.");
            stream.write(data.getBytes(StandardCharsets.UTF_8));
        }
    }

    private String loadPublicDocument() throws Exception {
        ContentResolver resolver = getContext().getContentResolver();
        Uri uri = findPublicDocument(resolver);
        if (uri == null) return "";
        try (ByteArrayOutputStream bytes = new ByteArrayOutputStream();
             InputStreamWithBuffer stream = new InputStreamWithBuffer(resolver.openInputStream(uri))) {
            if (stream.input == null) throw new Exception("Android could not open the backup file.");
            byte[] buffer = new byte[8192];
            int count;
            while ((count = stream.input.read(buffer)) != -1) bytes.write(buffer, 0, count);
            return new String(bytes.toByteArray(), StandardCharsets.UTF_8);
        }
    }

    private Uri findPublicDocument(ContentResolver resolver) {
        Uri collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI;
        String[] projection = { MediaStore.Downloads._ID };
        String selection = MediaStore.Downloads.DISPLAY_NAME + "=? AND "
            + MediaStore.Downloads.RELATIVE_PATH + "=?";
        String[] args = { SAVE_NAME, SAVE_FOLDER };
        try (Cursor cursor = resolver.query(collection, projection, selection, args, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                long id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Downloads._ID));
                return Uri.withAppendedPath(collection, Long.toString(id));
            }
        }
        return null;
    }

    private void saveLegacyDocument(String data) throws Exception {
        File folder = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "WHT");
        if (!folder.exists() && !folder.mkdirs()) throw new Exception("Could not create Downloads/WHT.");
        File file = new File(folder, SAVE_NAME);
        try (FileOutputStream stream = new FileOutputStream(file)) {
            stream.write(data.getBytes(StandardCharsets.UTF_8));
            stream.getFD().sync();
        }
        MediaScannerConnection.scanFile(getContext(), new String[]{file.getAbsolutePath()}, new String[]{SAVE_MIME}, null);
    }

    private String loadLegacyDocument() throws Exception {
        File file = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "WHT/" + SAVE_NAME);
        if (!file.exists()) return "";
        try (FileInputStream stream = new FileInputStream(file);
             ByteArrayOutputStream bytes = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[8192];
            int count;
            while ((count = stream.read(buffer)) != -1) bytes.write(buffer, 0, count);
            return new String(bytes.toByteArray(), StandardCharsets.UTF_8);
        }
    }

    @PermissionCallback
    private void storagePermissionResult(PluginCall call) {
        if (getPermissionState("storage") == PermissionState.GRANTED) {
            saveAppDataNow(call);
        } else {
            call.reject("Storage permission is required to create the WHT backup.");
        }
    }

    @PluginMethod
    public void savePng(PluginCall call) {
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P && getPermissionState("storage") != PermissionState.GRANTED) {
            requestPermissionForAlias("storage", call, "storagePermissionResultPng");
            return;
        }
        saveImage(call);
    }

    @PluginMethod
    public void emailPng(PluginCall call) {
        String data = call.getString("data");
        String fileName = call.getString("fileName", "worked-hours-week.png");
        String subject = call.getString("subject", "WHT hours export");
        if (data == null || data.isEmpty()) {
            call.reject("PNG data was missing.");
            return;
        }

        try {
            int comma = data.indexOf(',');
            String base64 = comma >= 0 ? data.substring(comma + 1) : data;
            byte[] bytes = Base64.decode(base64, Base64.DEFAULT);
            File folder = new File(getContext().getCacheDir(), "shared_exports");
            if (!folder.exists() && !folder.mkdirs()) throw new Exception("Could not create the temporary attachment folder.");
            File file = new File(folder, fileName);
            try (FileOutputStream stream = new FileOutputStream(file)) {
                stream.write(bytes);
            }

            Uri uri = FileProvider.getUriForFile(getContext(), getContext().getPackageName() + ".fileprovider", file);
            Intent email = new Intent(Intent.ACTION_SEND);
            email.setType("image/png");
            email.putExtra(Intent.EXTRA_SUBJECT, subject);
            email.putExtra(Intent.EXTRA_TEXT, "WorkedHoursTracker report attached.");
            email.putExtra(Intent.EXTRA_STREAM, uri);
            email.setClipData(ClipData.newRawUri("WHT hours report", uri));
            email.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            getActivity().startActivity(Intent.createChooser(email, "Email WHT export"));
            call.resolve();
        } catch (Exception error) {
            call.reject("Could not open an email app with the PNG attached: " + error.getMessage(), error);
        }
    }

    @PermissionCallback
    private void storagePermissionResultPng(PluginCall call) {
        if (getPermissionState("storage") == PermissionState.GRANTED) {
            saveImage(call);
        } else {
            call.reject("Storage permission is required to save the PNG to the Gallery.");
        }
    }

    private void saveImage(PluginCall call) {
        String data = call.getString("data");
        String fileName = call.getString("fileName", "worked-hours-week.png");
        if (data == null || data.isEmpty()) {
            call.reject("PNG data was missing.");
            return;
        }

        try {
            int comma = data.indexOf(',');
            String base64 = comma >= 0 ? data.substring(comma + 1) : data;
            byte[] bytes = Base64.decode(base64, Base64.DEFAULT);

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                saveWithMediaStore(call, bytes, fileName);
            } else {
                saveLegacy(call, bytes, fileName);
            }
        } catch (Exception error) {
            call.reject("Could not save the PNG to the Gallery: " + error.getMessage(), error);
        }
    }

    private void saveWithMediaStore(PluginCall call, byte[] bytes, String fileName) throws Exception {
        ContentResolver resolver = getContext().getContentResolver();
        ContentValues values = new ContentValues();
        values.put(MediaStore.Images.Media.DISPLAY_NAME, fileName);
        values.put(MediaStore.Images.Media.MIME_TYPE, "image/png");
        values.put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/WHT");
        values.put(MediaStore.Images.Media.IS_PENDING, 1);

        Uri uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
        if (uri == null) throw new Exception("Android could not create the Gallery image.");

        try (OutputStream stream = resolver.openOutputStream(uri)) {
            if (stream == null) throw new Exception("Android could not open the Gallery image.");
            stream.write(bytes);
        } catch (Exception error) {
            resolver.delete(uri, null, null);
            throw error;
        }

        values.clear();
        values.put(MediaStore.Images.Media.IS_PENDING, 0);
        resolver.update(uri, values, null, null);
        resolve(call, uri.toString());
    }

    private void saveLegacy(PluginCall call, byte[] bytes, String fileName) throws Exception {
        File folder = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "WHT");
        if (!folder.exists() && !folder.mkdirs()) throw new Exception("Could not create the Gallery folder.");
        File file = new File(folder, fileName);
        try (FileOutputStream stream = new FileOutputStream(file)) {
            stream.write(bytes);
        }
        MediaScannerConnection.scanFile(getContext(), new String[]{file.getAbsolutePath()}, new String[]{"image/png"}, null);
        resolve(call, Uri.fromFile(file).toString());
    }

    private void resolve(PluginCall call, String uri) {
        JSObject result = new JSObject();
        result.put("uri", uri);
        result.put("album", "WHT");
        call.resolve(result);
    }

    private static class InputStreamWithBuffer implements AutoCloseable {
        final java.io.InputStream input;
        InputStreamWithBuffer(java.io.InputStream input) { this.input = input; }
        public void close() throws java.io.IOException { if (input != null) input.close(); }
    }
}
JAVA

python - <<'PY'
from pathlib import Path
styles = Path("android/app/src/main/res/values/styles.xml")
if styles.exists():
    text = styles.read_text()
    text = text.replace("Theme.AppCompat.Light.", "Theme.AppCompat.DayNight.")
    styles.write_text(text)
PY

echo "Added native Android PNG export to Pictures/WHT."
