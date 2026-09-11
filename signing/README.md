# WHT app signing key

`wht-release.jks` is the app's permanent Android signing key. Keep it private and make a secure backup of it.

The same signing key is required for Android to recognise a newly built APK as an update to the existing installation instead of requiring an uninstall.

The keystore password is supplied through the `WHT_KEYSTORE_PASSWORD` environment variable and is intentionally not stored in the project.
