from pathlib import Path
import os, re, shutil

root = Path(__file__).resolve().parents[1]
gradle = root / 'android' / 'app' / 'build.gradle'
keystore_src = root / 'signing' / 'wht-release.jks'
keystore_dst = root / 'android' / 'app' / 'wht-release.jks'

if not gradle.exists():
    raise SystemExit('android/app/build.gradle was not found.')
if not keystore_src.exists():
    raise SystemExit('signing/wht-release.jks was not found.')

shutil.copy2(keystore_src, keystore_dst)
text = gradle.read_text()

# Ensure versionCode is always newer for each CI build unless explicitly supplied.
vc = os.environ.get('WHT_VERSION_CODE')
if vc and re.search(r'versionCode\s+\d+', text):
    text = re.sub(r'versionCode\s+\d+', f'versionCode {vc}', text, count=1)
elif 'versionCode' in text and 'WHT_VERSION_CODE' not in text:
    text = re.sub(r'versionCode\s+\d+', 'versionCode (System.currentTimeMillis() / 1000).toInteger()', text, count=1)

# Keep the installed Android app version aligned with the visible WHT version.
version_name = os.environ.get('WHT_VERSION_NAME', '2.84')
if re.search(r'versionName\s+["\'][^"\']+["\']', text):
    text = re.sub(r'versionName\s+["\'][^"\']+["\']', f'versionName "{version_name}"', text, count=1)
else:
    raise SystemExit('Could not locate versionName in android/app/build.gradle.')

password = os.environ.get('WHT_KEYSTORE_PASSWORD')
if not password:
    raise SystemExit('WHT_KEYSTORE_PASSWORD is required for a signed release build.')

signing_block = '''\n    signingConfigs {\n        release {\n            storeFile file("wht-release.jks")\n            storePassword System.getenv("WHT_KEYSTORE_PASSWORD")\n            keyAlias "wht"\n            keyPassword System.getenv("WHT_KEYSTORE_PASSWORD")\n        }\n    }\n'''

if 'signingConfigs {' not in text:
    marker = '\n    buildTypes {'
    if marker not in text:
        raise SystemExit('Could not locate buildTypes block in android/app/build.gradle.')
    text = text.replace(marker, signing_block + marker, 1)

# Add signing to the *buildTypes.release* block.
# Do not match the earlier signingConfigs.release block.
build_types_pos = text.find("buildTypes {")
if build_types_pos == -1:
    raise SystemExit("Could not locate buildTypes block in android/app/build.gradle.")
release_pos = text.find("release {", build_types_pos)
if release_pos == -1:
    raise SystemExit("Could not locate buildTypes.release block in android/app/build.gradle.")

# Find the end of the buildTypes.release block so we can avoid inserting
# anything into the signingConfigs.release block.
brace_start = text.find("{", release_pos)
depth = 0
end_pos = None
for i in range(brace_start, len(text)):
    if text[i] == "{":
        depth += 1
    elif text[i] == "}":
        depth -= 1
        if depth == 0:
            end_pos = i
            break
if end_pos is None:
    raise SystemExit("Could not parse buildTypes.release block in android/app/build.gradle.")

release_block = text[release_pos:end_pos + 1]
if "signingConfig signingConfigs.release" not in release_block:
    insert_at = release_pos + len("release {")
    text = text[:insert_at] + "\n            signingConfig signingConfigs.release" + text[insert_at:]

gradle.write_text(text)
print('Release signing configured.')
