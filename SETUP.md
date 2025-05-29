# OneDrive Integration Setup Guide

This guide will help you configure OneDrive integration for the Document Scanner app.

## Quick Setup

1. **Run the setup script:**

   ```bash
   dart run setup_env.dart
   ```

2. **Register your app in Azure AD:**

   - Go to [Azure Portal](https://portal.azure.com)
   - Navigate to: Azure Active Directory → App registrations
   - Click "New registration"
   - Set name: "Document Scanner App" (or any name you prefer)
   - Set redirect URI: `https://login.microsoftonline.com/common/oauth2/nativeclient`
   - After creation, copy the "Application (client) ID"

3. **Configure permissions:**

   - Go to API permissions → Add a permission
   - Choose Microsoft Graph → Delegated permissions
   - Add: `Files.ReadWrite` and `Files.ReadWrite.All` (optional)
   - Grant admin consent if required

4. **Update your .env file:**

   ```bash
   ONEDRIVE_CLIENT_ID=your-actual-client-id-here
   ```

5. **Run the app:**
   ```bash
   flutter run
   ```

## Environment Variables

| Variable                | Required | Default                                                        | Description                      |
| ----------------------- | -------- | -------------------------------------------------------------- | -------------------------------- |
| `ONEDRIVE_CLIENT_ID`    | Yes      | `your-azure-client-id-here`                                    | Azure AD Application (Client) ID |
| `ONEDRIVE_REDIRECT_URI` | No       | `https://login.microsoftonline.com/common/oauth2/nativeclient` | OAuth redirect URI               |
| `ONEDRIVE_SCOPES`       | No       | `files.readwrite offline_access`                               | OneDrive API scopes              |

## User Experience

### Option 1: Pre-configured (Recommended)

- Developer sets up Azure AD app once
- Users just authenticate with their Microsoft account
- No technical knowledge required for end users

### Option 2: Custom Client ID

- Each user can register their own Azure AD app
- More control but requires technical knowledge
- Users enter their own Client ID in app settings

## Security Best Practices

1. **Never commit .env files:**

   - The `.env` file is already in `.gitignore`
   - Only commit `template.env` with dummy values

2. **Keep Client ID confidential:**

   - Don't share your Client ID publicly
   - Consider using app secrets for production apps

3. **Use appropriate scopes:**
   - Only request necessary permissions
   - `files.readwrite` is sufficient for most use cases

## Troubleshooting

### "Could not load .env file"

- Run `dart run setup_env.dart` to create the file
- Make sure the file is in the project root directory
- Check that the file contains valid key=value pairs

### "Client ID not found"

- Verify your `.env` file has `ONEDRIVE_CLIENT_ID=your-id`
- Make sure there are no extra spaces around the equals sign
- Restart the app after updating `.env`

### Authentication fails

- Verify the Client ID is correct in Azure AD
- Check that redirect URI matches exactly
- Ensure API permissions are granted

### App permissions denied

- Go to Azure AD → App registrations → Your app → API permissions
- Make sure Microsoft Graph permissions are added
- Click "Grant admin consent" if available

## Development Notes

- The app loads environment variables on startup
- Environment loading failures are logged as warnings
- Users can still enter custom Client IDs even with .env configured
- The `.env` file takes precedence over user-entered values

## Support

If you encounter issues:

1. Check the debug console for error messages
2. Verify your Azure AD app configuration
3. Ensure all dependencies are installed: `flutter pub get`
4. Try recreating the `.env` file: `dart run setup_env.dart`
