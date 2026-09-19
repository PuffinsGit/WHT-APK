#!/usr/bin/env bash
set -euo pipefail

# Generate launcher-icon variants for every WHT background preset. Android
# activity aliases let the native app select the icon that matches the current
# app palette while retaining the correct black/white logo for the system theme.
LIGHT_SOURCE="resources/icon-light.png"
DARK_SOURCE="resources/icon-dark.png"
RES="android/app/src/main/res"
JAVA_DIR="android/app/src/main/java/com/workedhourstracker/app"
MANIFEST="android/app/src/main/AndroidManifest.xml"

for source in "$LIGHT_SOURCE" "$DARK_SOURCE"; do
  if [[ ! -f "$source" ]]; then
    echo "Missing $source"
    exit 1
  fi
done

if [[ ! -f "$MANIFEST" || ! -d "$JAVA_DIR" ]]; then
  echo "Android project has not been generated. Run npx cap add android first."
  exit 1
fi

python - <<'PY'
from pathlib import Path
from PIL import Image

res = Path("android/app/src/main/res")
sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
palettes = {
    "dark_midnight": ("#11182a", "#253354", "#4a3670"),
    "dark_deep_blue": ("#0d2b3d", "#194b69", "#304a7e"),
    "dark_deep_purple": ("#271641", "#4a2b70", "#70408a"),
    "dark_graphite": ("#1b222c", "#35414f", "#4b5563"),
    "dark_forest": ("#142b22", "#205341", "#34705d"),
    "dark_ocean": ("#10313c", "#155b6b", "#268091"),
    "dark_burgundy": ("#331720", "#612538", "#843851"),
    "dark_warm_slate": ("#29231f", "#4b4037", "#625548"),
    "light_soft_sky": ("#dcecff", "#f1ecff", "#ffdff3"),
    "light_blue_mist": ("#d9f1ff", "#e8f2ff", "#dfe4ff"),
    "light_lavender": ("#eee5ff", "#f6edff", "#ffe5f4"),
    "light_soft_mint": ("#dff8ef", "#eefaf5", "#e5f2ff"),
    "light_peach": ("#fff0df", "#fff7ed", "#ffe4dc"),
    "light_rose": ("#ffe7ef", "#fff2f7", "#f3e5ff"),
    "light_sage": ("#e4f1df", "#f3f7e9", "#e0efe9"),
    "light_warm_sand": ("#f7ecd9", "#fff8ea", "#eee3cf"),
}

def rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))

def transparent_logo(path, light_mode):
    image = Image.open(path).convert("RGBA")
    pixels = []
    for r, g, b, _ in image.getdata():
        alpha = 255 - min(r, g, b) if light_mode else max(r, g, b)
        pixels.append((r, g, b, alpha if alpha >= 8 else 0))
    image.putdata(pixels)
    return image

dark_logo = transparent_logo(Path("resources/icon-dark.png"), False)
light_logo = transparent_logo(Path("resources/icon-light.png"), True)

def gradient(size, colours):
    stops = [rgb(value) for value in colours]
    image = Image.new("RGB", (size, size))
    pixels = image.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / max(1, 2 * (size - 1))
            if t <= 0.52:
                local, left, right = t / 0.52, stops[0], stops[1]
            else:
                local, left, right = (t - 0.52) / 0.48, stops[1], stops[2]
            pixels[x, y] = tuple(round(left[i] + (right[i] - left[i]) * local) for i in range(3))
    return image.convert("RGBA")

for key, colours in palettes.items():
    canvas = gradient(512, colours)
    logo = light_logo if key.startswith("light_") else dark_logo
    logo = logo.resize((446, 446), Image.Resampling.LANCZOS)
    canvas.alpha_composite(logo, ((512 - 446) // 2, (512 - 446) // 2))
    for density, size in sizes.items():
        out_dir = res / f"mipmap-{density}"
        out_dir.mkdir(parents=True, exist_ok=True)
        canvas.resize((size, size), Image.Resampling.LANCZOS).save(
            out_dir / f"ic_launcher_{key}.png", optimize=True
        )

# System surfaces such as active notifications resolve the icon from the
# application manifest, not from the selected launcher activity alias.
# Give the application its own WHT icon in each system theme.
for density in sizes:
    day = res / f"mipmap-{density}"
    night = res / f"mipmap-night-{density}"
    night.mkdir(parents=True, exist_ok=True)
    (day / "wht_app_icon.png").write_bytes((day / "ic_launcher_light_soft_sky.png").read_bytes())
    (night / "wht_app_icon.png").write_bytes((day / "ic_launcher_dark_midnight.png").read_bytes())

for path in (
    res / "mipmap-anydpi-v26/ic_launcher.xml",
    res / "mipmap-anydpi-v26/ic_launcher_round.xml",
    res / "mipmap-night-anydpi-v26/ic_launcher.xml",
    res / "mipmap-night-anydpi-v26/ic_launcher_round.xml",
):
    path.unlink(missing_ok=True)

print("Generated palette-matched WHT launcher icons.")
PY

cat > "$JAVA_DIR/WhtLauncherIcon.java" <<'JAVA'
package com.workedhourstracker.app;

import android.content.ComponentName;
import android.content.Context;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import org.json.JSONObject;

final class WhtLauncherIcon {
    private static final String[] ALIASES = {
        "LauncherDarkMidnight", "LauncherDarkDeepBlue", "LauncherDarkDeepPurple", "LauncherDarkGraphite",
        "LauncherDarkForest", "LauncherDarkOcean", "LauncherDarkBurgundy", "LauncherDarkWarmSlate",
        "LauncherLightSoftSky", "LauncherLightBlueMist", "LauncherLightLavender", "LauncherLightSoftMint",
        "LauncherLightPeach", "LauncherLightRose", "LauncherLightSage", "LauncherLightWarmSand"
    };

    static void sync(Context context, JSONObject state) {
        boolean light = (context.getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK)
            != Configuration.UI_MODE_NIGHT_YES;
        String background = state.optString(light ? "lightBackground" : "darkBackground", "").toLowerCase();
        String selected = light ? lightAlias(background) : darkAlias(background);
        PackageManager manager = context.getPackageManager();
        ComponentName selectedComponent = new ComponentName(context, context.getPackageName() + "." + selected);
        if (manager.getComponentEnabledSetting(selectedComponent) != PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
            manager.setComponentEnabledSetting(selectedComponent, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP);
        }
        for (String alias : ALIASES) {
            if (alias.equals(selected)) continue;
            ComponentName component = new ComponentName(context, context.getPackageName() + "." + alias);
            if (manager.getComponentEnabledSetting(component) != PackageManager.COMPONENT_ENABLED_STATE_DISABLED) {
                manager.setComponentEnabledSetting(component, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP);
            }
        }
    }

    private static String darkAlias(String background) {
        if (background.contains("#0d2b3d")) return "LauncherDarkDeepBlue";
        if (background.contains("#271641")) return "LauncherDarkDeepPurple";
        if (background.contains("#1b222c")) return "LauncherDarkGraphite";
        if (background.contains("#142b22")) return "LauncherDarkForest";
        if (background.contains("#10313c")) return "LauncherDarkOcean";
        if (background.contains("#331720")) return "LauncherDarkBurgundy";
        if (background.contains("#29231f")) return "LauncherDarkWarmSlate";
        return "LauncherDarkMidnight";
    }

    private static String lightAlias(String background) {
        if (background.contains("#d9f1ff")) return "LauncherLightBlueMist";
        if (background.contains("#eee5ff")) return "LauncherLightLavender";
        if (background.contains("#dff8ef")) return "LauncherLightSoftMint";
        if (background.contains("#fff0df")) return "LauncherLightPeach";
        if (background.contains("#ffe7ef")) return "LauncherLightRose";
        if (background.contains("#e4f1df")) return "LauncherLightSage";
        if (background.contains("#f7ecd9")) return "LauncherLightWarmSand";
        return "LauncherLightSoftSky";
    }
}
JAVA

cat > "$JAVA_DIR/WhtIconThemeReceiver.java" <<'JAVA'
package com.workedhourstracker.app;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
public class WhtIconThemeReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        WhtLauncherIcon.sync(context, WhtWidgetStyle.state(context));
    }
}
JAVA

python - <<'PY'
from pathlib import Path
import re

manifest = Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text()
application = re.search(r'<application\b[^>]*>', text)
if not application or 'android:icon=' not in application.group(0) or 'android:roundIcon=' not in application.group(0):
    raise SystemExit("Could not find the application icons in AndroidManifest.xml")
app_tag = re.sub(r'android:icon="[^"]+"', 'android:icon="@mipmap/wht_app_icon"', application.group(0))
app_tag = re.sub(r'android:roundIcon="[^"]+"', 'android:roundIcon="@mipmap/wht_app_icon"', app_tag)
text = text[:application.start()] + app_tag + text[application.end():]
activity = re.search(r'<activity\b[^>]*android:name="\.MainActivity"[\s\S]*?</activity>', text)
if not activity:
    raise SystemExit("Could not find MainActivity in AndroidManifest.xml")
block = activity.group(0)
for intent_filter in re.findall(r'\s*<intent-filter\b[^>]*>[\s\S]*?</intent-filter>', block):
    if "android.intent.action.MAIN" in intent_filter and "android.intent.category.LAUNCHER" in intent_filter:
        block = block.replace(intent_filter, "")
text = text[:activity.start()] + block + text[activity.end():]

start_marker = "        <!-- WHT_DYNAMIC_ICONS_START -->"
end_marker = "        <!-- WHT_DYNAMIC_ICONS_END -->"
if start_marker in text and end_marker in text:
    before, rest = text.split(start_marker, 1)
    _, after = rest.split(end_marker, 1)
    text = before + after

variants = [
    ("LauncherDarkMidnight", "dark_midnight", True),
    ("LauncherDarkDeepBlue", "dark_deep_blue", False),
    ("LauncherDarkDeepPurple", "dark_deep_purple", False),
    ("LauncherDarkGraphite", "dark_graphite", False),
    ("LauncherDarkForest", "dark_forest", False),
    ("LauncherDarkOcean", "dark_ocean", False),
    ("LauncherDarkBurgundy", "dark_burgundy", False),
    ("LauncherDarkWarmSlate", "dark_warm_slate", False),
    ("LauncherLightSoftSky", "light_soft_sky", False),
    ("LauncherLightBlueMist", "light_blue_mist", False),
    ("LauncherLightLavender", "light_lavender", False),
    ("LauncherLightSoftMint", "light_soft_mint", False),
    ("LauncherLightPeach", "light_peach", False),
    ("LauncherLightRose", "light_rose", False),
    ("LauncherLightSage", "light_sage", False),
    ("LauncherLightWarmSand", "light_warm_sand", False),
]

aliases = [start_marker]
for name, resource, enabled in variants:
    aliases.append(f'''        <activity-alias android:name=".{name}" android:targetActivity=".MainActivity" android:enabled="{str(enabled).lower()}" android:exported="true" android:icon="@mipmap/ic_launcher_{resource}" android:roundIcon="@mipmap/ic_launcher_{resource}" android:label="WHT">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity-alias>''')
aliases.append('        <receiver android:name=".WhtIconThemeReceiver" android:exported="false"><intent-filter><action android:name="android.intent.action.CONFIGURATION_CHANGED" /></intent-filter></receiver>')
aliases.append(end_marker)
text = text.replace("    </application>", "\n".join(aliases) + "\n    </application>")
manifest.write_text(text)
print("Configured dynamic WHT launcher aliases.")
PY
