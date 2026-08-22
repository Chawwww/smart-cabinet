# Smart Cabinet Finder 1.0.2

Smart Cabinet Finder combines cloud inventory management with physical ESP32 cabinet control from one Android application.

## Highlights

- Manage cabinets, boxes, categories, tags, quantities, expiry dates, and item history.
- Link a different BLE device to each cabinet and switch from one app.
- Automatically reconnect to the most recently selected cabinet.
- Maintain an Android background BLE connection with an ongoing notification.
- Control upper/lower cabinet doors and LEDs and receive door-state notifications.
- Display linked BLE device totals and active connection status.
- Delete owned cabinet records with a confirmation prompt.
- Share cabinets directly or through expiring link/QR invitations with role-based access.
- Use English, Malay, or Chinese with light and dark themes.

## Android package

- App version: `1.0.2+3`
- Distribution status: private/test signing

## Important release notes

- Private Firebase native configuration files are not included.
- Gemini features require `GEMINI_API_KEY` at build time. Production AI requests should use an authenticated backend rather than embedding a private key in the APK.
- The current release build uses the Android debug signing key. Configure a private release keystore before public production distribution.
- Only one BLE cabinet is actively connected at a time.
- Force-stopping the Android app terminates background BLE until it is reopened.
- No open-source license has been selected yet.
