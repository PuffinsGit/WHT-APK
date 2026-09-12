#!/usr/bin/env bash
set -euo pipefail
JAVA_DIR="android/app/src/main/java/com/workedhourstracker/app"
RES_DIR="android/app/src/main/res"
MANIFEST="android/app/src/main/AndroidManifest.xml"
[[ -d "$JAVA_DIR" && -f "$MANIFEST" ]] || { echo "Run npx cap add android first."; exit 1; }
mkdir -p "$RES_DIR/layout" "$RES_DIR/xml" "$RES_DIR/drawable" "$RES_DIR/drawable-night" "$RES_DIR/drawable-nodpi" "$RES_DIR/values" "$RES_DIR/values-night"
cp "wht/header-logo-light.png" "$RES_DIR/drawable/wht_widget_logo.png"
cp "wht/header-logo.png" "$RES_DIR/drawable-night/wht_widget_logo.png"
cp "wht/header-logo-light.png" "$RES_DIR/drawable/wht_notification_logo.png"
cp "wht/header-logo.png" "$RES_DIR/drawable-night/wht_notification_logo.png"
cp "wht/header-logo.png" "$RES_DIR/drawable/wht_notification_small.png"

# Samsung and some other launchers require previewImage even when previewLayout
# is supplied. Generate a representative 0% Shift Progress preview.
python3 - <<'PY'
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

size = 360
canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(canvas)
draw.rounded_rectangle((4, 4, 356, 356), radius=34, fill=(12, 19, 39, 255), outline=(86, 70, 130, 255), width=2)
try:
    bold = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 25)
    percent_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 54)
    small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 16)
    time_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 20)
except OSError:
    bold = percent_font = small = time_font = ImageFont.load_default()

def centered(text, y, font, fill):
    box = draw.textbbox((0, 0), text, font=font)
    draw.text(((size - (box[2] - box[0])) / 2, y), text, font=font, fill=fill)

centered("Today's Shift", 22, bold, "white")
ring = (76, 74, 284, 282)
draw.ellipse(ring, outline=(255, 255, 255, 55), width=17)
centered("0%", 138, percent_font, "white")
centered("COMPLETE", 202, small, (255, 255, 255, 190))
centered("12:30 pm – 5:00 pm", 315, time_font, "white")

logo = Image.open("wht/header-logo.png").convert("RGBA")
logo.thumbnail((42, 42), Image.Resampling.LANCZOS)
canvas.alpha_composite(logo, (size - logo.width - 12, 12))
canvas.save("android/app/src/main/res/drawable-nodpi/wht_shift_progress_preview.png")

ring_preview = Image.new("RGBA", (280, 280), (0, 0, 0, 0))
ring_draw = ImageDraw.Draw(ring_preview)
ring_draw.ellipse((18, 18, 262, 262), outline=(255, 255, 255, 70), width=20)
box = ring_draw.textbbox((0, 0), "0%", font=percent_font)
ring_draw.text(((280 - (box[2] - box[0])) / 2, 100), "0%", font=percent_font, fill="white")
box = ring_draw.textbbox((0, 0), "COMPLETE", font=small)
ring_draw.text(((280 - (box[2] - box[0])) / 2, 171), "COMPLETE", font=small, fill=(255, 255, 255, 190))
ring_preview.save("android/app/src/main/res/drawable-nodpi/wht_progress_ring_preview.png")
PY

cat > "$RES_DIR/layout/wht_clock_widget.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android" android:layout_width="match_parent" android:layout_height="match_parent" android:theme="@android:style/Theme.DeviceDefault.DayNight">
  <ImageView android:id="@+id/widget_background" android:layout_width="match_parent" android:layout_height="match_parent" android:scaleType="fitXY" android:src="@drawable/wht_widget_background" android:contentDescription="@null" />
  <LinearLayout android:layout_width="match_parent" android:layout_height="match_parent" android:orientation="horizontal" android:padding="8dp">
    <TextView android:id="@+id/widget_clock_in" android:layout_width="0dp" android:layout_height="match_parent" android:layout_weight="1" android:layout_marginEnd="4dp" android:gravity="center" android:background="@drawable/wht_widget_clock_in" android:text="Clock In" android:textColor="@color/wht_widget_text" android:textSize="15sp" android:textStyle="bold" />
    <TextView android:id="@+id/widget_clock_out" android:layout_width="0dp" android:layout_height="match_parent" android:layout_weight="1" android:layout_marginStart="4dp" android:gravity="center" android:background="@drawable/wht_widget_clock_out" android:text="Clock Out" android:textColor="@color/wht_widget_text" android:textSize="15sp" android:textStyle="bold" />
  </LinearLayout>
  <TextView android:id="@+id/widget_confirmation" android:layout_width="wrap_content" android:layout_height="36dp" android:layout_gravity="center" android:background="@drawable/wht_widget_confirmation" android:elevation="10dp" android:gravity="center" android:minWidth="118dp" android:paddingLeft="18dp" android:paddingRight="18dp" android:textColor="@color/wht_widget_text" android:textSize="14sp" android:textStyle="bold" android:visibility="gone" />
</FrameLayout>
XML

cat > "$RES_DIR/layout/wht_next_shift_widget.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android" android:id="@+id/next_shift_root" android:layout_width="match_parent" android:layout_height="match_parent">
  <ImageView android:id="@+id/next_shift_background" android:layout_width="match_parent" android:layout_height="match_parent" android:scaleType="fitXY" android:src="@drawable/wht_widget_background" android:contentDescription="@null" />
  <LinearLayout android:layout_width="match_parent" android:layout_height="match_parent" android:orientation="vertical" android:paddingLeft="12dp" android:paddingTop="5dp" android:paddingRight="12dp" android:paddingBottom="6dp">
    <TextView android:id="@+id/next_shift_title" android:layout_width="match_parent" android:layout_height="23dp" android:gravity="center" android:paddingLeft="38dp" android:paddingRight="38dp" android:text="Upcoming Shifts" android:textAlignment="center" android:textColor="#FFFFFF" android:textSize="15sp" android:textStyle="bold" />
    <LinearLayout android:layout_width="match_parent" android:layout_height="0dp" android:layout_weight="1" android:orientation="horizontal" android:gravity="center_vertical">
      <LinearLayout android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:gravity="center" android:orientation="vertical">
        <TextView android:id="@+id/shift_one_date" android:layout_width="match_parent" android:layout_height="wrap_content" android:gravity="center" android:maxLines="1" android:text="No upcoming shift" android:textAlignment="center" android:textColor="#FFFFFF" android:textSize="16sp" android:textStyle="bold" />
        <TextView android:id="@+id/shift_one_time" android:layout_width="match_parent" android:layout_height="wrap_content" android:gravity="center" android:maxLines="1" android:text="Add one in Schedule" android:textAlignment="center" android:textColor="#D9FFFFFF" android:textSize="13sp" />
      </LinearLayout>
      <LinearLayout android:id="@+id/shift_two_group" android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:gravity="center" android:orientation="vertical">
        <TextView android:id="@+id/shift_two_date" android:layout_width="match_parent" android:layout_height="wrap_content" android:gravity="center" android:maxLines="1" android:textAlignment="center" android:textColor="#FFFFFF" android:textSize="16sp" android:textStyle="bold" />
        <TextView android:id="@+id/shift_two_time" android:layout_width="match_parent" android:layout_height="wrap_content" android:gravity="center" android:maxLines="1" android:textAlignment="center" android:textColor="#D9FFFFFF" android:textSize="13sp" />
      </LinearLayout>
      <LinearLayout android:id="@+id/shift_three_group" android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:gravity="center" android:orientation="vertical" android:visibility="gone">
        <TextView android:id="@+id/shift_three_date" android:layout_width="match_parent" android:layout_height="wrap_content" android:gravity="center" android:maxLines="1" android:textAlignment="center" android:textColor="#FFFFFF" android:textSize="16sp" android:textStyle="bold" />
        <TextView android:id="@+id/shift_three_time" android:layout_width="match_parent" android:layout_height="wrap_content" android:gravity="center" android:maxLines="1" android:textAlignment="center" android:textColor="#D9FFFFFF" android:textSize="13sp" />
      </LinearLayout>
    </LinearLayout>
  </LinearLayout>
  <ImageView android:layout_width="28dp" android:layout_height="28dp" android:layout_gravity="top|right" android:layout_marginTop="4dp" android:layout_marginRight="6dp" android:src="@drawable/wht_widget_logo" android:contentDescription="WHT" />
</FrameLayout>
XML

cat > "$RES_DIR/layout/wht_shift_progress_widget.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android" android:id="@+id/progress_widget_root" android:layout_width="match_parent" android:layout_height="match_parent">
  <ImageView android:id="@+id/progress_widget_background" android:layout_width="match_parent" android:layout_height="match_parent" android:scaleType="fitXY" android:src="@drawable/wht_widget_background" android:contentDescription="@null" />
  <LinearLayout android:layout_width="match_parent" android:layout_height="match_parent" android:gravity="center" android:orientation="vertical" android:padding="10dp">
    <TextView android:id="@+id/progress_widget_title" android:layout_width="match_parent" android:layout_height="wrap_content" android:gravity="center" android:text="Today's Shift" android:textColor="#FFFFFF" android:textSize="14sp" android:textStyle="bold" />
    <ImageView android:id="@+id/progress_ring" android:layout_width="match_parent" android:layout_height="0dp" android:layout_weight="1" android:adjustViewBounds="true" android:scaleType="centerInside" android:src="@drawable/wht_progress_ring_preview" android:contentDescription="Shift completion" />
    <TextView android:id="@+id/progress_shift_time" android:layout_width="match_parent" android:layout_height="wrap_content" android:gravity="center" android:maxLines="1" android:text="No shift scheduled" android:textColor="#E6FFFFFF" android:textSize="13sp" android:textStyle="bold" />
  </LinearLayout>
  <ImageView android:layout_width="25dp" android:layout_height="25dp" android:layout_gravity="top|right" android:layout_marginTop="7dp" android:layout_marginRight="8dp" android:src="@drawable/wht_widget_logo" android:contentDescription="WHT" />
</FrameLayout>
XML

cat > "$RES_DIR/drawable/wht_widget_background.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<level-list xmlns:android="http://schemas.android.com/apk/res/android">
  <item android:maxLevel="0"><shape><gradient android:angle="0" android:startColor="#DCEcff" android:endColor="#FFDFF3"/><corners android:radius="22dp"/></shape></item>
  <item android:maxLevel="1"><shape><gradient android:angle="0" android:startColor="#D9F1FF" android:endColor="#DFE4FF"/><corners android:radius="22dp"/></shape></item>
  <item android:maxLevel="2"><shape><gradient android:angle="0" android:startColor="#EEE5FF" android:endColor="#FFE5F4"/><corners android:radius="22dp"/></shape></item>
  <item android:maxLevel="10000"><shape><gradient android:angle="0" android:startColor="#DFF8EF" android:endColor="#E5F2FF"/><corners android:radius="22dp"/></shape></item>
</level-list>
XML
cat > "$RES_DIR/drawable-night/wht_widget_background.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<level-list xmlns:android="http://schemas.android.com/apk/res/android">
  <item android:maxLevel="0"><shape><gradient android:angle="0" android:startColor="#060810" android:endColor="#291744"/><corners android:radius="22dp"/></shape></item>
  <item android:maxLevel="1"><shape><gradient android:angle="0" android:startColor="#04131F" android:endColor="#17234B"/><corners android:radius="22dp"/></shape></item>
  <item android:maxLevel="2"><shape><gradient android:angle="0" android:startColor="#10091C" android:endColor="#401B54"/><corners android:radius="22dp"/></shape></item>
  <item android:maxLevel="10000"><shape><gradient android:angle="0" android:startColor="#090B0F" android:endColor="#282D36"/><corners android:radius="22dp"/></shape></item>
</level-list>
XML
cat > "$RES_DIR/values/wht_widget_colors.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?><resources><color name="wht_widget_text">#FF11151C</color></resources>
XML
cat > "$RES_DIR/values-night/wht_widget_colors.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?><resources><color name="wht_widget_text">#FFFFFFFF</color></resources>
XML
cat > "$RES_DIR/drawable/wht_widget_clock_in.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?><shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle"><solid android:color="#DD238B45"/><corners android:radius="16dp"/><stroke android:width="1dp" android:color="#44FFFFFF"/></shape>
XML
cat > "$RES_DIR/drawable/wht_widget_clock_out.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?><shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle"><solid android:color="#DDC73D52"/><corners android:radius="16dp"/><stroke android:width="1dp" android:color="#44FFFFFF"/></shape>
XML
cat > "$RES_DIR/drawable/wht_widget_confirmation.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?><shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle"><solid android:color="#D9181D27"/><corners android:radius="18dp"/><stroke android:width="1dp" android:color="#66FFFFFF"/></shape>
XML
cat > "$RES_DIR/xml/wht_clock_widget_info.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?><appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android" android:initialLayout="@layout/wht_clock_widget" android:previewLayout="@layout/wht_clock_widget" android:minWidth="320dp" android:minHeight="40dp" android:minResizeWidth="40dp" android:minResizeHeight="40dp" android:resizeMode="horizontal|vertical" android:targetCellWidth="5" android:targetCellHeight="1" android:updatePeriodMillis="1800000" android:widgetCategory="home_screen" />
XML
cat > "$RES_DIR/xml/wht_next_shift_widget_info.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?><appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android" android:initialLayout="@layout/wht_next_shift_widget" android:previewLayout="@layout/wht_next_shift_widget" android:minWidth="180dp" android:minHeight="40dp" android:minResizeWidth="40dp" android:minResizeHeight="40dp" android:resizeMode="horizontal|vertical" android:targetCellWidth="3" android:targetCellHeight="1" android:updatePeriodMillis="1800000" android:widgetCategory="home_screen" />
XML
cat > "$RES_DIR/xml/wht_shift_progress_widget_info.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?><appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android" android:initialLayout="@layout/wht_shift_progress_widget" android:previewLayout="@layout/wht_shift_progress_widget" android:previewImage="@drawable/wht_shift_progress_preview" android:minWidth="180dp" android:minHeight="110dp" android:minResizeWidth="40dp" android:minResizeHeight="40dp" android:resizeMode="horizontal|vertical" android:targetCellWidth="3" android:targetCellHeight="2" android:updatePeriodMillis="1800000" android:widgetCategory="home_screen" />
XML
cat > "$JAVA_DIR/WhtWidgetStyle.java" <<'JAVA'
package com.workedhourstracker.app;
import android.content.Context; import android.graphics.*; import org.json.JSONObject;
final class WhtWidgetStyle {
 static final String PREFS="wht_device_save", DATA="app_data";
 static JSONObject state(Context c){try{JSONObject s=new JSONObject(c.getSharedPreferences(PREFS,0).getString(DATA,"{}"));int night=c.getResources().getConfiguration().uiMode&android.content.res.Configuration.UI_MODE_NIGHT_MASK;s.put("themeMode",night==android.content.res.Configuration.UI_MODE_NIGHT_YES?"dark":"light");return s;}catch(Exception e){return new JSONObject();}}
 static int[] palette(JSONObject s){boolean light="light".equals(s.optString("themeMode","dark"));String raw=s.optString(light?"lightBackground":"darkBackground",light?"linear-gradient(145deg, #dcecff, #ffdff3)":"linear-gradient(145deg, #060810, #291744)");java.util.regex.Matcher m=java.util.regex.Pattern.compile("#[0-9a-fA-F]{6}").matcher(raw);int first=light?Color.rgb(220,236,255):Color.rgb(6,8,16),last=light?Color.rgb(255,223,243):Color.rgb(41,23,68);if(m.find())try{first=Color.parseColor(m.group());}catch(Exception ignored){}while(m.find())try{last=Color.parseColor(m.group());}catch(Exception ignored){}return new int[]{first,last};}
 static int paletteLevel(JSONObject s){boolean light="light".equals(s.optString("themeMode","dark"));String raw=s.optString(light?"lightBackground":"darkBackground","").toLowerCase(java.util.Locale.US);if(raw.contains(light?"#d9f1ff":"#04131f"))return 1;if(raw.contains(light?"#eee5ff":"#10091c"))return 2;if(raw.contains(light?"#dff8ef":"#090b0f"))return 3;return 0;}
 static Bitmap background(JSONObject s){int[] colors=palette(s);Bitmap x=Bitmap.createBitmap(600,110,Bitmap.Config.ARGB_8888);Paint p=new Paint(1);p.setShader(new LinearGradient(0,0,600,110,colors[0],colors[1],Shader.TileMode.CLAMP));new Canvas(x).drawRoundRect(0,0,600,110,24,24,p);return x;}
 static int blend(int a,int b,float n){return Color.rgb(Math.round(Color.red(a)+(Color.red(b)-Color.red(a))*n),Math.round(Color.green(a)+(Color.green(b)-Color.green(a))*n),Math.round(Color.blue(a)+(Color.blue(b)-Color.blue(a))*n));}
}
JAVA

cat > "$JAVA_DIR/WhtClockNotification.java" <<'JAVA'
package com.workedhourstracker.app;
import android.app.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.graphics.BitmapFactory;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import org.json.JSONObject;
import java.text.SimpleDateFormat;
import java.util.*;
final class WhtClockNotification {
 static final String CHANNEL="wht_clock_status_silent_v2";
 static final int ID=2450;
 static final Handler LIVE_HANDLER=new Handler(Looper.getMainLooper());
 static Runnable liveTick;

 static void sync(Context c,JSONObject state){
  try{
   Date now=new Date();
   String key=new SimpleDateFormat("yyyy-MM-dd",Locale.US).format(now);
   JSONObject all=state.optJSONObject("entries");
   JSONObject e=all==null?null:all.optJSONObject(key);
   String start=e==null?"":e.optString("start","");
   boolean active=e!=null&&!start.isEmpty()&&e.optString("finish","").isEmpty();
   NotificationManager m=(NotificationManager)c.getSystemService(Context.NOTIFICATION_SERVICE);
   ClockWidgetProvider.refreshAll(c);
   NextShiftWidgetProvider.refreshAll(c);
   ShiftProgressWidgetProvider.refreshAll(c);
   if(!active){m.cancel(ID);scheduleTick(c,false);scheduleLiveTick(c,false);return;}
   if(Build.VERSION.SDK_INT>=33&&c.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)return;

   if(Build.VERSION.SDK_INT>=26){
    NotificationChannel ch=new NotificationChannel(CHANNEL,"Live Clocked In Status",NotificationManager.IMPORTANCE_DEFAULT);
    ch.setDescription("Shows the current WHT shift date and elapsed time");
    ch.setShowBadge(true);
    ch.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
    ch.setSound(null,null);
    m.createNotificationChannel(ch);
   }

   SimpleDateFormat parser=new SimpleDateFormat("yyyy-MM-dd HH:mm",Locale.US);
   parser.setLenient(false);
   Date started=parser.parse(key+" "+start);
   long startedAt=started==null?System.currentTimeMillis():started.getTime();
   String dayDate=new SimpleDateFormat("EEE, d MMM",Locale.getDefault()).format(now);
   String startLabel=new SimpleDateFormat(state.optBoolean("use24Hour",true)?"HH:mm":"h:mm a",Locale.getDefault()).format(new Date(startedAt));
   if(!state.optBoolean("use24Hour",true))startLabel=startLabel.toLowerCase(Locale.getDefault());
   String elapsedLabel=elapsedLabel(startedAt,System.currentTimeMillis());
   ShiftProgressWidgetProvider.TodayShift scheduledShift=ShiftProgressWidgetProvider.today(state);
   int shiftPercent=ShiftProgressWidgetProvider.completion(state,scheduledShift);
   String progressLabel=shiftPercent+"% COMPLETE";

   Intent open=new Intent(c,MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP|Intent.FLAG_ACTIVITY_SINGLE_TOP);
   PendingIntent pi=PendingIntent.getActivity(c,2450,open,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
   Intent clockOutIntent=new Intent(c,ClockWidgetProvider.class).setAction(ClockWidgetProvider.OUT);
   PendingIntent clockOutPi=PendingIntent.getBroadcast(c,2452,clockOutIntent,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
   Notification.Builder b=Build.VERSION.SDK_INT>=26?new Notification.Builder(c,CHANNEL):new Notification.Builder(c);
   b.setSmallIcon(R.drawable.wht_notification_small)
    .setLargeIcon(BitmapFactory.decodeResource(c.getResources(),R.drawable.wht_notification_logo))
    .setContentTitle("Clocked In At "+startLabel)
    .setContentText(elapsedLabel)
    .setSubText(progressLabel)
    .setProgress(Math.max(100,shiftPercent),shiftPercent,false)
    .setWhen(startedAt)
    .setShowWhen(false)
    .setUsesChronometer(false)
    .setContentIntent(pi)
    .setOngoing(true)
    .setOnlyAlertOnce(true)
    .setSound(null)
    .setDefaults(0)
    .setNumber(1)
    .setCategory("stopwatch")
    .setVisibility(Notification.VISIBILITY_PUBLIC)
    .addAction(new Notification.Action.Builder(R.drawable.wht_notification_small,"Clock Out",clockOutPi).build())
    .addAction(new Notification.Action.Builder(R.drawable.wht_notification_small,"Open WHT",pi).build());
   // Request Android 16 Live Update promotion. Samsung maps eligible promoted
   // ongoing notifications onto its Now Bar surface.
   requestPromotion(b);
   setShortStatus(b,dayDate+" • "+elapsedLabel+" • "+shiftPercent+"%");
   if(Build.VERSION.SDK_INT>=26)b.setBadgeIconType(Notification.BADGE_ICON_SMALL);
   m.notify(ID,b.build());
   scheduleTick(c,true);
   scheduleLiveTick(c,true);
  }catch(Exception ignored){}
 }
 static void requestPromotion(Notification.Builder b){
  try{
   String key=(String)Notification.class.getField("EXTRA_REQUEST_PROMOTED_ONGOING").get(null);
   b.getExtras().putBoolean(key,true);
  }catch(Exception ignored){
   // Compatibility fallback for Android builds exposing the extra before the
   // public SDK field is available to the compiler.
   b.getExtras().putBoolean("android.requestPromotedOngoing",true);
  }
 }
 static String elapsedLabel(long startedAt,long now){
  long seconds=Math.max(0,(now-startedAt)/1000L);
  long hours=seconds/3600L;
  long mins=(seconds%3600L)/60L;
  return hours+"h "+mins+"m";
 }
static void setShortStatus(Notification.Builder b,String text){
  try{
   Notification.Builder.class.getMethod("setShortCriticalText",String.class).invoke(b,text);
  }catch(Exception first){
   try{Notification.Builder.class.getMethod("setShortCriticalText",CharSequence.class).invoke(b,text);}catch(Exception ignored){}
  }
}
 static PendingIntent tickIntent(Context c){
  return PendingIntent.getBroadcast(c,2451,new Intent(c,WhtNotificationTickReceiver.class),PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
 }
 static void scheduleTick(Context c,boolean active){
  AlarmManager a=(AlarmManager)c.getSystemService(Context.ALARM_SERVICE);
  PendingIntent tick=tickIntent(c);
  if(!active){a.cancel(tick);return;}
  long delay=60000L-(System.currentTimeMillis()%60000L)+250L;
  a.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP,android.os.SystemClock.elapsedRealtime()+delay,tick);
 }
 static void scheduleLiveTick(Context c,boolean active){
  if(liveTick!=null)LIVE_HANDLER.removeCallbacks(liveTick);
  liveTick=null;
  if(!active)return;
  Context app=c.getApplicationContext();
  liveTick=()->sync(app,WhtWidgetStyle.state(app));
  LIVE_HANDLER.postDelayed(liveTick,1000L);
 }
}
JAVA

cat > "$JAVA_DIR/WhtClockSound.java" <<'JAVA'
package com.workedhourstracker.app;
import android.content.Context;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.net.Uri;
final class WhtClockSound {
 static void play(Context c){
  try{
   Uri tone=RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);
   Ringtone ringtone=RingtoneManager.getRingtone(c.getApplicationContext(),tone);
   if(ringtone!=null)ringtone.play();
  }catch(Exception ignored){}
 }
}
JAVA

cat > "$JAVA_DIR/WhtNotificationTickReceiver.java" <<'JAVA'
package com.workedhourstracker.app;
import android.content.*;
public class WhtNotificationTickReceiver extends BroadcastReceiver {
 public void onReceive(Context c,Intent i){WhtClockNotification.sync(c,WhtWidgetStyle.state(c));}
}
JAVA

cat > "$JAVA_DIR/ClockWidgetProvider.java" <<'JAVA'
package com.workedhourstracker.app;
import android.app.*; import android.appwidget.*; import android.content.*; import android.view.View; import android.widget.*; import org.json.JSONObject; import java.text.SimpleDateFormat; import java.util.*;
public class ClockWidgetProvider extends AppWidgetProvider {
 static final String IN="com.workedhourstracker.app.CLOCK_IN", OUT="com.workedhourstracker.app.CLOCK_OUT";
 public void onUpdate(Context c,AppWidgetManager m,int[] ids){JSONObject s=WhtWidgetStyle.state(c);for(int id:ids)m.updateAppWidget(id,view(c,s));}
 public static void refreshAll(Context c){AppWidgetManager m=AppWidgetManager.getInstance(c);int[] ids=m.getAppWidgetIds(new ComponentName(c,ClockWidgetProvider.class));JSONObject s=WhtWidgetStyle.state(c);for(int id:ids)m.updateAppWidget(id,view(c,s));}
 static RemoteViews view(Context c,JSONObject s){RemoteViews v=new RemoteViews(c.getPackageName(),R.layout.wht_clock_widget);v.setImageViewResource(R.id.widget_background,R.drawable.wht_widget_background);v.setInt(R.id.widget_background,"setImageLevel",WhtWidgetStyle.paletteLevel(s));v.setViewVisibility(R.id.widget_confirmation,View.GONE);v.setOnClickPendingIntent(R.id.widget_clock_in,pending(c,IN,101));v.setOnClickPendingIntent(R.id.widget_clock_out,pending(c,OUT,102));return v;}
 static PendingIntent pending(Context c,String a,int n){return PendingIntent.getBroadcast(c,n,new Intent(c,ClockWidgetProvider.class).setAction(a),PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);}
 public void onReceive(Context c,Intent i){super.onReceive(c,i);String a=i.getAction();if(Intent.ACTION_CONFIGURATION_CHANGED.equals(a)){refreshAll(c);return;}if(!IN.equals(a)&&!OUT.equals(a))return;PendingResult result=goAsync();new Thread(()->{record(c,IN.equals(a)?"start":"finish",IN.equals(a)?"Clocked In":"Clocked Out");try{Thread.sleep(1900);}catch(InterruptedException ignored){Thread.currentThread().interrupt();}refreshAll(c);result.finish();}).start();}
 void record(Context c,String field,String message){try{Date now=new Date();String date=new SimpleDateFormat("yyyy-MM-dd",Locale.US).format(now),time=new SimpleDateFormat("HH:mm",Locale.US).format(now);JSONObject s=WhtWidgetStyle.state(c),entries=s.optJSONObject("entries");if(entries==null){entries=new JSONObject();s.put("entries",entries);}JSONObject e=entries.optJSONObject(date);if(e==null)e=new JSONObject();e.put(field,time);if("start".equals(field))e.remove("finish");entries.put(date,e);s.put("savedAt",System.currentTimeMillis());c.getSharedPreferences(WhtWidgetStyle.PREFS,0).edit().putString(WhtWidgetStyle.DATA,s.toString()).commit();WhtClockNotification.sync(c,s);WhtClockSound.play(c);showConfirmation(c,s,message);}catch(Exception e){Toast.makeText(c,"WHT could not save the time",Toast.LENGTH_LONG).show();}}
 static void showConfirmation(Context c,JSONObject s,String message){AppWidgetManager m=AppWidgetManager.getInstance(c);for(int id:m.getAppWidgetIds(new ComponentName(c,ClockWidgetProvider.class))){RemoteViews v=view(c,s);v.setTextViewText(R.id.widget_confirmation,message);v.setViewVisibility(R.id.widget_confirmation,View.VISIBLE);m.updateAppWidget(id,v);}}
}
JAVA

cat > "$JAVA_DIR/NextShiftWidgetProvider.java" <<'JAVA'
package com.workedhourstracker.app;
import android.app.*; import android.appwidget.*; import android.content.*; import android.os.Bundle; import android.view.View; import android.widget.*; import org.json.JSONObject; import java.text.SimpleDateFormat; import java.util.*;
public class NextShiftWidgetProvider extends AppWidgetProvider {
 public void onUpdate(Context c,AppWidgetManager m,int[] ids){JSONObject s=WhtWidgetStyle.state(c);for(int id:ids)m.updateAppWidget(id,view(c,s,isWide(m,id)));}
 public void onAppWidgetOptionsChanged(Context c,AppWidgetManager m,int id,Bundle o){m.updateAppWidget(id,view(c,WhtWidgetStyle.state(c),o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)>=300));}
 static boolean isWide(AppWidgetManager m,int id){return m.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)>=300;}
 public static void refreshAll(Context c){AppWidgetManager m=AppWidgetManager.getInstance(c);int[] ids=m.getAppWidgetIds(new ComponentName(c,NextShiftWidgetProvider.class));JSONObject s=WhtWidgetStyle.state(c);for(int id:ids)m.updateAppWidget(id,view(c,s,isWide(m,id)));}
 static RemoteViews view(Context c,JSONObject s,boolean wide){RemoteViews v=new RemoteViews(c.getPackageName(),R.layout.wht_next_shift_widget);v.setImageViewBitmap(R.id.next_shift_background,WhtWidgetStyle.background(s));boolean light="light".equals(s.optString("themeMode","dark"));int text=light?android.graphics.Color.BLACK:android.graphics.Color.WHITE,secondary=light?0xCC000000:0xD9FFFFFF;int[] primaryIds={R.id.next_shift_title,R.id.shift_one_date,R.id.shift_two_date,R.id.shift_three_date};int[] secondaryIds={R.id.shift_one_time,R.id.shift_two_time,R.id.shift_three_time};for(int id:primaryIds)v.setTextColor(id,text);for(int id:secondaryIds)v.setTextColor(id,secondary);List<Shift> shifts=next(s);bind(v,shifts,0,R.id.shift_one_date,R.id.shift_one_time,R.id.shift_two_group,s);bind(v,shifts,1,R.id.shift_two_date,R.id.shift_two_time,R.id.shift_two_group,s);bind(v,shifts,2,R.id.shift_three_date,R.id.shift_three_time,R.id.shift_three_group,s);v.setViewVisibility(R.id.shift_three_group,wide&&shifts.size()>2?View.VISIBLE:View.GONE);if(shifts.isEmpty()){v.setTextViewText(R.id.shift_one_date,"No upcoming shift");v.setTextViewText(R.id.shift_one_time,"Add one in Schedule");v.setViewVisibility(R.id.shift_two_group,View.GONE);}Intent open=new Intent(c,MainActivity.class).putExtra("wht_open_screen","schedule").addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP|Intent.FLAG_ACTIVITY_SINGLE_TOP);v.setOnClickPendingIntent(R.id.next_shift_root,PendingIntent.getActivity(c,201,open,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE));return v;}
 public void onReceive(Context c,Intent i){super.onReceive(c,i);if(Intent.ACTION_CONFIGURATION_CHANGED.equals(i.getAction()))refreshAll(c);}
 static void bind(RemoteViews v,List<Shift> a,int i,int dateId,int timeId,int groupId,JSONObject s){if(i>=a.size()){if(i>0)v.setViewVisibility(groupId,View.GONE);return;}Shift n=a.get(i);v.setViewVisibility(groupId,View.VISIBLE);v.setTextViewText(dateId,new SimpleDateFormat("EEE, d MMM",Locale.getDefault()).format(n.start));SimpleDateFormat t=new SimpleDateFormat(s.optBoolean("use24Hour",true)?"HH:mm":"h:mm a",Locale.getDefault());v.setTextViewText(timeId,t.format(n.start)+(n.finish==null?"":" – "+t.format(n.finish)));}
 static List<Shift> next(JSONObject s){ArrayList<Shift> found=new ArrayList<>();JSONObject all=s.optJSONObject("scheduleEntries");if(all==null)return found;Date now=new Date();Iterator<String> keys=all.keys();while(keys.hasNext()){String d=keys.next();JSONObject e=all.optJSONObject(d);if(e==null||e.optString("start","").isEmpty())continue;try{SimpleDateFormat p=new SimpleDateFormat("yyyy-MM-dd HH:mm",Locale.US);p.setLenient(false);Date start=p.parse(d+" "+e.optString("start")),finish=e.optString("finish","").isEmpty()?null:p.parse(d+" "+e.optString("finish"));if(finish!=null&&!finish.after(start)){Calendar c=Calendar.getInstance();c.setTime(finish);c.add(Calendar.DATE,1);finish=c.getTime();}if((finish==null?start:finish).before(now))continue;found.add(new Shift(start,finish));}catch(Exception ignored){}}Collections.sort(found,(a,b)->a.start.compareTo(b.start));return found.size()>3?new ArrayList<>(found.subList(0,3)):found;}
 static class Shift{final Date start,finish;Shift(Date s,Date f){start=s;finish=f;}}
}
JAVA

cat > "$JAVA_DIR/ShiftProgressWidgetProvider.java" <<'JAVA'
package com.workedhourstracker.app;
import android.app.*; import android.appwidget.*; import android.content.*; import android.graphics.*; import android.os.Bundle; import android.widget.RemoteViews; import org.json.JSONObject; import java.text.SimpleDateFormat; import java.util.*;
public class ShiftProgressWidgetProvider extends AppWidgetProvider {
 public void onUpdate(Context c,AppWidgetManager m,int[] ids){JSONObject s=WhtWidgetStyle.state(c);for(int id:ids)m.updateAppWidget(id,view(c,s,isWide(m,id)));}
 public void onAppWidgetOptionsChanged(Context c,AppWidgetManager m,int id,Bundle o){m.updateAppWidget(id,view(c,WhtWidgetStyle.state(c),o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)>=180));}
 static boolean isWide(AppWidgetManager m,int id){return m.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)>=180;}
 public static void refreshAll(Context c){AppWidgetManager m=AppWidgetManager.getInstance(c);int[] ids=m.getAppWidgetIds(new ComponentName(c,ShiftProgressWidgetProvider.class));JSONObject s=WhtWidgetStyle.state(c);for(int id:ids)m.updateAppWidget(id,view(c,s,isWide(m,id)));}
 static RemoteViews view(Context c,JSONObject s,boolean wide){RemoteViews v=new RemoteViews(c.getPackageName(),R.layout.wht_shift_progress_widget);v.setImageViewBitmap(R.id.progress_widget_background,background(s,wide));TodayShift shift=today(s);int percent=completion(s,shift);v.setImageViewBitmap(R.id.progress_ring,ring(s,percent,wide));v.setTextViewText(R.id.progress_shift_time,shift==null?"No shift scheduled":timeLabel(s,shift));int text="light".equals(s.optString("themeMode","dark"))?Color.BLACK:Color.WHITE;v.setTextColor(R.id.progress_widget_title,text);v.setTextColor(R.id.progress_shift_time,text);Intent open=new Intent(c,MainActivity.class).putExtra("wht_open_screen","worked_today").addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP|Intent.FLAG_ACTIVITY_SINGLE_TOP);v.setOnClickPendingIntent(R.id.progress_widget_root,PendingIntent.getActivity(c,2750,open,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE));return v;}
 static TodayShift today(JSONObject s){try{Date now=new Date();String key=new SimpleDateFormat("yyyy-MM-dd",Locale.US).format(now);JSONObject all=s.optJSONObject("scheduleEntries"),e=all==null?null:all.optJSONObject(key);if(e==null||e.optString("start","").isEmpty()||e.optString("finish","").isEmpty())return null;SimpleDateFormat p=new SimpleDateFormat("yyyy-MM-dd HH:mm",Locale.US);p.setLenient(false);Date start=p.parse(key+" "+e.optString("start")),finish=p.parse(key+" "+e.optString("finish"));if(!finish.after(start)){Calendar cal=Calendar.getInstance();cal.setTime(finish);cal.add(Calendar.DATE,1);finish=cal.getTime();}return new TodayShift(start,finish);}catch(Exception ignored){return null;}}
 static int completion(JSONObject s,TodayShift shift){if(shift==null)return 0;try{String key=new SimpleDateFormat("yyyy-MM-dd",Locale.US).format(new Date());JSONObject all=s.optJSONObject("entries"),e=all==null?null:all.optJSONObject(key);if(e==null||e.optString("start","").isEmpty())return 0;SimpleDateFormat p=new SimpleDateFormat("yyyy-MM-dd HH:mm",Locale.US);p.setLenient(false);Date actualStart=p.parse(key+" "+e.optString("start"));Date progressPoint=new Date();String finishValue=e.optString("finish","");if(!finishValue.isEmpty()){progressPoint=p.parse(key+" "+finishValue);if(!progressPoint.after(actualStart)){Calendar overnight=Calendar.getInstance();overnight.setTime(progressPoint);overnight.add(Calendar.DATE,1);progressPoint=overnight.getTime();}}long scheduledDuration=Math.max(1L,shift.finish.getTime()-shift.start.getTime());long workedDuration=Math.max(0L,progressPoint.getTime()-actualStart.getTime());return (int)Math.max(0,Math.round(workedDuration*100f/scheduledDuration));}catch(Exception ignored){return 0;}}
 static String timeLabel(JSONObject s,TodayShift shift){SimpleDateFormat f=new SimpleDateFormat(s.optBoolean("use24Hour",true)?"HH:mm":"h:mm a",Locale.getDefault());return f.format(shift.start)+" – "+f.format(shift.finish);}
 static Bitmap background(JSONObject s,boolean wide){int[] colors=WhtWidgetStyle.palette(s);int w=wide?540:360;Bitmap x=Bitmap.createBitmap(w,360,Bitmap.Config.ARGB_8888);Paint p=new Paint(1);p.setShader(new LinearGradient(0,0,w,360,colors[0],colors[1],Shader.TileMode.CLAMP));new Canvas(x).drawRoundRect(0,0,w,360,34,34,p);return x;}
 static Bitmap ring(JSONObject s,int percent,boolean wide){int size=wide?300:280;Bitmap x=Bitmap.createBitmap(size,size,Bitmap.Config.ARGB_8888);Canvas c=new Canvas(x);boolean light="light".equals(s.optString("themeMode","dark"));int text=light?Color.BLACK:Color.WHITE,accent=light?Color.rgb(90,70,205):Color.rgb(174,150,255);Paint p=new Paint(Paint.ANTI_ALIAS_FLAG);float stroke=size*.075f,margin=stroke;RectF oval=new RectF(margin,margin,size-margin,size-margin);p.setStyle(Paint.Style.STROKE);p.setStrokeWidth(stroke);p.setStrokeCap(Paint.Cap.ROUND);p.setColor(light?0x33201A3A:0x33FFFFFF);c.drawArc(oval,-90,360,false,p);p.setColor(accent);c.drawArc(oval,-90,Math.min(100,percent)*3.6f,false,p);p.setStyle(Paint.Style.FILL);p.setTextAlign(Paint.Align.CENTER);p.setTypeface(Typeface.create(Typeface.DEFAULT,Typeface.BOLD));p.setTextSize(size*.23f);p.setColor(text);c.drawText(percent+"%",size/2f,size*.52f,p);p.setTypeface(Typeface.create(Typeface.DEFAULT,Typeface.NORMAL));p.setTextSize(size*.085f);p.setColor(light?0xCC000000:0xBFFFFFFF);c.drawText("COMPLETE",size/2f,size*.66f,p);return x;}
 public void onReceive(Context c,Intent i){super.onReceive(c,i);if(Intent.ACTION_CONFIGURATION_CHANGED.equals(i.getAction()))refreshAll(c);}
 static class TodayShift{final Date start,finish;TodayShift(Date start,Date finish){this.start=start;this.finish=finish;}}
}
JAVA

python - <<'PY'
from pathlib import Path
p=Path("android/app/src/main/AndroidManifest.xml"); text=p.read_text()
r='''        <receiver android:name=".ClockWidgetProvider" android:exported="true" android:label="Clock In &amp; Out"><intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE" /><action android:name="android.intent.action.CONFIGURATION_CHANGED" /></intent-filter><meta-data android:name="android.appwidget.provider" android:resource="@xml/wht_clock_widget_info" /></receiver>
        <receiver android:name=".NextShiftWidgetProvider" android:exported="true" android:label="Upcoming Shifts"><intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE" /><action android:name="android.intent.action.CONFIGURATION_CHANGED" /></intent-filter><meta-data android:name="android.appwidget.provider" android:resource="@xml/wht_next_shift_widget_info" /></receiver>
        <receiver android:name=".ShiftProgressWidgetProvider" android:exported="true" android:label="Shift Progress"><intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE" /><action android:name="android.intent.action.CONFIGURATION_CHANGED" /></intent-filter><meta-data android:name="android.appwidget.provider" android:resource="@xml/wht_shift_progress_widget_info" /></receiver>
        <receiver android:name=".WhtNotificationTickReceiver" android:exported="false" />
'''
if '.ClockWidgetProvider' not in text:text=text.replace('    </application>',r+'    </application>')
if '.ShiftProgressWidgetProvider' not in text:
    text=text.replace('    </application>','        <receiver android:name=".ShiftProgressWidgetProvider" android:exported="true" android:label="Shift Progress"><intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE" /><action android:name="android.intent.action.CONFIGURATION_CHANGED" /></intent-filter><meta-data android:name="android.appwidget.provider" android:resource="@xml/wht_shift_progress_widget_info" /></receiver>\n    </application>')
if '.WhtNotificationTickReceiver' not in text:
    text=text.replace('    </application>','        <receiver android:name=".WhtNotificationTickReceiver" android:exported="false" />\n    </application>')
p.write_text(text)
PY
echo "Added styled WHT Clock, Next Scheduled Shift, and Shift Progress home-screen widgets."
