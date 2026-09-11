# WHT app signing key

`wht-release.jks` is the app's permanent Android signing key. Keep it private and make a secure backup of it.

The same signing key is required for Android to recognise a newly built APK as an update to the existing installation instead of requiring an uninstall.

The keystore password is supplied through the `WHT_KEYSTORE_PASSWORD` environment variable and is intentionally not stored in the project.

Key alias: `wht`

Certificate SHA-256 fingerprint:
`25:93:57:43:10:A3:F0:E2:C3:5C:D7:98:8F:8C:73:5E:E7:C7:82:4A:94:89:81:57:95:13:CB:77:64:2C:AE:E8`
