#!/usr/bin/env python3
"""Keep the Capacitor Activity alive when Android changes night mode."""
from pathlib import Path
import re

manifest = Path("android/app/src/main/AndroidManifest.xml")
source = manifest.read_text(encoding="utf-8")
activity = re.search(r'<activity\b[^>]*android:name="\.MainActivity"[^>]*>', source, re.S)
if activity is None:
    raise SystemExit("MainActivity not found in generated Android manifest")
tag = activity.group()
config = re.search(r'android:configChanges="([^"]*)"', tag)
if config is None:
    raise SystemExit("MainActivity has no configChanges attribute")
changes = config.group(1).split("|")
if "uiMode" not in changes:
    changes.append("uiMode")
    updated = tag[:config.start(1)] + "|".join(changes) + tag[config.end(1):]
    manifest.write_text(source[:activity.start()] + updated + source[activity.end():], encoding="utf-8")
