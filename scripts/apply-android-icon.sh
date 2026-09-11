#!/usr/bin/env bash
set -euo pipefail

# Generate light and dark native Android launcher icons. Android selects the
# mipmap-night resources automatically when the device uses dark mode.
# Uses Python/Pillow so the GitHub runner does not need ImageMagick.
LIGHT_SOURCE="resources/icon-light.png"
DARK_SOURCE="resources/icon-dark.png"
RES="android/app/src/main/res"

for source in "$LIGHT_SOURCE" "$DARK_SOURCE"; do
  if [[ ! -f "$source" ]]; then
    echo "Missing $source"
    exit 1
  fi
done

python - <<'PY'
from pathlib import Path
from PIL import Image

light_source = Path("resources/icon-light.png")
dark_source = Path("resources/icon-dark.png")
res = Path("android/app/src/main/res")

sizes = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}

def write_icon_set(source, night=False):
    img = Image.open(source).convert("RGBA")
    for density, size in sizes.items():
        qualifier = f"night-{density}" if night else density
        out_dir = res / f"mipmap-{qualifier}"
        out_dir.mkdir(parents=True, exist_ok=True)
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(out_dir / "ic_launcher.png", optimize=True)
        resized.save(out_dir / "ic_launcher_round.png", optimize=True)

write_icon_set(light_source)
write_icon_set(dark_source, night=True)

for path in (
    res / "mipmap-anydpi-v26/ic_launcher.xml",
    res / "mipmap-anydpi-v26/ic_launcher_round.xml",
    res / "mipmap-night-anydpi-v26/ic_launcher.xml",
    res / "mipmap-night-anydpi-v26/ic_launcher_round.xml",
):
    path.unlink(missing_ok=True)

print("Applied light and dark WHT launcher icons to Android day/night resources.")
PY
