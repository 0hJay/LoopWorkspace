# Pebble App Deployment Guide

This guide covers deploying the Loop CGM watchapp to the Rebble Appstore.

## Option 1: Rebble Appstore (Recommended for Distribution)

### Prerequisites
1. **Rebble Developer Account** - Sign up at [dev-portal.rebble.io](https://dev-portal.rebble.io/)
2. **Built .pbw file** - Run `./build.sh` in the `pebble/` directory

### Steps

#### 1. Build the App
```bash
cd pebble/
./build.sh
```

This creates `loop-cgm.pbw` ready for upload.

#### 2. Log into Rebble Developer Portal
- Go to [https://dev-portal.rebble.io/](https://dev-portal.rebble.io/)
- Sign in with your Rebble account (same as your Pebble/Rebble app login)

#### 3. Create New Watchapp Listing
- Click **"Add a Watchapp"**
- Fill in the details:
  - **Title:** `Loop CGM Monitor`
  - **Category:** `Health & Fitness`
  - **Source Code URL:** `https://github.com/MinimusClawdius/LoopWorkspace`
  - **Support Email:** Your email
- Upload icons:
  - **Large Icon:** Use `pebble/resources/images/icon.png` (scaled to 144x144)
  - **Small Icon:** Use `pebble/resources/images/icon.png` (scaled to 48x48)
- Click **"Create"**

#### 4. Upload Release
- On the listing page, click **"Add a release"**
- Upload `loop-cgm.pbw`
- Add release notes (optional):
  ```
  v1.0.0 - Initial Release
  - Blood glucose monitoring with trend arrows
  - IOB/COB display
  - Loop status indicator
  - Bolus requests (requires iPhone confirmation)
  - Carb entry (requires iPhone confirmation)
  ```
- Click **"Save"**
- Click **"Publish"** next to the release to make it live

#### 5. Add Asset Collection (Screenshots)
- Click **"Manage Asset Collections"**
- Click **"Create"** for each platform (Basalt, Chalk, Diorite, Emery)
- Add:
  - **Description:** 
    ```
    Monitor your Loop insulin pump CGM data directly on your Pebble watch. 
    
    Features:
    • Real-time blood glucose display with trend arrows
    • Insulin on board (IOB) monitoring
    • Loop status indicator
    • Bolus and carb entry with iPhone confirmation
    • Off-grid operation (Bluetooth only)
    
    Requires the Loop iOS app with PebbleService integration.
    ```
  - **Screenshots:** Take screenshots from Pebble emulator or actual watch
    - Main CGM screen
    - Bolus entry screen
    - Carb entry screen
    - Command menu
  - **Marketing Banner:** (optional) 720x320 banner image

#### 6. Publish
- Once all asset collections are complete, click **"Publish"**
- The app will be available in the Rebble Appstore
- Get the shareable link and deep link from the listing page

### After Publishing
- Users can find it by searching "Loop CGM" in the Pebble app
- Direct link: `https://apps.rebble.io/en_US/application/[app-id]`
- Deep link for mobile: `pebble://appstore/[app-id]`

---

## Option 2: Direct Installation (For Personal Use)

### Via Phone IP
```bash
cd pebble/
./build.sh --install <phone-ip>
```

### Via Cloud (Rebble)
```bash
cd pebble/
./build.sh --install
```

### Side-load
1. Transfer `loop-cgm.pbw` to your phone
2. Open the file with the Pebble app
3. Follow installation prompts

---

## Option 3: Private Distribution

For beta testing or private distribution:

1. Follow the Appstore steps above
2. Instead of "Publish", click **"Publish Privately"**
3. Share the direct link with testers
4. Note: Once made public, an app cannot be made private again

---

## Updating the App

1. Make code changes
2. Increment version in `appinfo.json` and `package.json`:
   ```json
   "versionCode": 2,
   "versionLabel": "1.1.0"
   ```
3. Build: `./build.sh`
4. Go to your listing on dev-portal.rebble.io
5. Click "Add a release"
6. Upload new .pbw
7. Publish the release

---

## Required Assets Checklist

### For Watchapp Listing
- [ ] Large icon (144x144 PNG)
- [ ] Small icon (48x48 PNG)
- [ ] Title
- [ ] Category
- [ ] Source code URL
- [ ] Support email
- [ ] .pbw release file

### For Each Platform Asset Collection
- [ ] Description
- [ ] 1-5 screenshots
- [ ] (Optional) Marketing banner (720x320)
- [ ] (Optional) Up to 3 header images

### Platforms to Support
- [ ] Aplite (Pebble, Pebble Steel)
- [ ] Basalt (Pebble Time)
- [ ] Chalk (Pebble Time Round)
- [ ] Diorite (Pebble 2)
- [ ] Emery (Pebble Time 2)

---

## Troubleshooting

### "Missing: At least one published release"
- Upload the .pbw file and click "Publish" next to the release

### "Missing: A complete X asset collection"
- Create asset collection for each platform with screenshots and description

### Build fails
- Ensure Pebble SDK is installed
- Check that all source files are present
- Try `pebble clean` before building

### App not appearing in search
- May take a few minutes to index after publishing
- Ensure app is marked as "Published" not "Draft"

---

## Resources

- [Rebble Developer Portal](https://dev-portal.rebble.io/)
- [Pebble Developer Docs](https://developer.rebble.io/)
- [Rebble Appstore](https://apps.rebble.io/)
- [LoopDocs](https://loopkit.github.io/loopdocs/)
