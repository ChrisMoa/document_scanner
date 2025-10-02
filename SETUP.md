# Nextcloud Integration Setup Guide

This guide will help you configure Nextcloud integration for the Document Scanner app.

## Quick Setup

1. **Create a Nextcloud App Password:**

   - Log in to your Nextcloud web UI
   - Open Settings → Security
   - Create a new App Password (copy it once displayed)

2. **Connect in the app:**

   - Open the app → Settings → Cloud & Sync → Nextcloud Integration
   - Enter server URL, username, and app password
   - Tap "Connect"

3. **Run the app:**

   ```bash
   flutter run
   ```

## Configuration Storage

- Credentials are stored securely on-device using `SharedPreferences`.
- You can update or revoke them anytime from Settings → Cloud & Sync.

## Security Best Practices

1. **Use App Passwords:**

   - Prefer app passwords instead of your main password

3. **HTTPS only:**

   - Ensure your Nextcloud server uses HTTPS

## Troubleshooting

### "Connection failed"

- Verify server URL, username, and app password
- Make sure your server is reachable from the device
- Try your credentials via a WebDAV client to verify

## Development Notes

- Nextcloud credentials are configured in-app and persisted via `SharedPreferences`.
- Users can enter or change credentials anytime in Settings.

## Support

If you encounter issues:

1. Check the debug console for error messages
2. Verify your Nextcloud credentials
3. Ensure all dependencies are installed: `flutter pub get`
