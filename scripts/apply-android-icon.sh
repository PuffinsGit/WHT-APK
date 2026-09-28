#!/usr/bin/env bash
set -euo pipefail

# Generate launcher-icon variants for every WHT background preset. Android
# a stable Android launcher entry retains the current app task while the
# icon follows the device's light or dark mode.
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

print("Generated day and night WHT launcher icons.")
PY

# Use one stable launcher component. Changing activity aliases while WHT is
# foreground can remove the running task from the launcher on some devices.
# Android chooses the day/night mipmap variant automatically.
cat > "$JAVA_DIR/WhtLauncherIcon.java" <<'JAVA'
package com.workedhourstracker.app;
import android.content.Context;
import org.json.JSONObject;
final class WhtLauncherIcon {
    static void sync(Context context, JSONObject state) {
        // The permanent MainActivity launcher icon follows the device theme.
    }
}
JAVA

python - <<'PY'
from pathlib import Path
import re
manifest = Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text()
application = re.search(r'<application\b[^>]*>', text)
if not application:
    raise SystemExit("Could not find application in AndroidManifest.xml")
tag = application.group()
for attribute in ("icon", "roundIcon"):
    tag = re.sub(r'android:' + attribute + r'="[^"]+"',
                 'android:' + attribute + '="@mipmap/wht_app_icon"', tag)
text = text[:application.start()] + tag + text[application.end():]
if 'android.intent.category.LAUNCHER' not in text:
    raise SystemExit("The permanent MainActivity launcher entry is missing")
manifest.write_text(text)
print("Configured stable day/night WHT launcher icon.")
PY
