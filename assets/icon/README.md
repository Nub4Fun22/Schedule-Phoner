# App icon

Put your launcher icon here as:

```
assets/icon/app_icon.png
```

Requirements:
- **PNG** format
- **Square**, ideally **1024×1024** px (512×512 minimum)

Once this file exists and you push it, the CI automatically generates every
Android icon size (via `flutter_launcher_icons`) and the next APK build uses it
as the app logo. No other steps needed.

## How to add it (easiest — right in GitHub)

1. Save the burning-calendar image on your computer as `app_icon.png`
   (make it square — crop to 1024×1024 if needed).
2. In the GitHub repo, open the `assets/icon/` folder.
3. Click **Add file → Upload files**.
4. Drag `app_icon.png` in and commit to `main`.
5. That push triggers a new build; the fresh APK on the **latest** release will
   have your logo.
