# Browser Build Deployment Guide - LoopWorkspace with Pebble Integration

## Overview

This guide covers deploying your customized Loop app (with PebbleService integration) using the **Browser Build** method via GitHub Actions and TestFlight.

**Reference:** https://loopkit.github.io/loopdocs/browser/bb-overview/

---

## ✅ What's Already Done

Your LoopWorkspace fork now includes:

1. **PebbleService Integration**
   - `PebbleService/` folder with all Swift files
   - Integrated into `LoopAppManager.swift`
   - Settings UI toggle in `SettingsView+PebbleSection.swift`

2. **Code Changes Committed**
   - Branch: `feature/pebble-integration`
   - Loop submodule updated with Pebble integration

---

## 🚨 Important: Browser Build Considerations

### The Challenge

Browser builds use **GitHub Actions** to compile your code in the cloud. This means:

1. **All files must be in Git** - PebbleService files need to be tracked
2. **Xcode project must reference them** - Files added to `.xcodeproj` target
3. **Submodule changes must be committed** - Loop submodule updates need to be pushed

### What You Need to Do

#### Step 1: Ensure PebbleService Files Are in Git

```bash
cd /workspace/LoopWorkspace

# Check if PebbleService is tracked
git status

# If not tracked, add it:
git add PebbleService/
git commit -m "Add PebbleService framework"
```

#### Step 2: Update Loop Submodule Reference

Since you modified files in the `Loop` submodule:

```bash
cd /workspace/LoopWorkspace

# Check submodule status
git status
# Should show: Modified but uncommitted changes in submodule 'Loop'

# Commit changes in submodule (already done)
cd Loop
git add .
git commit -m "feat: Add Pebble settings UI"
cd ..

# Update submodule reference in main repo
git add Loop
git commit -m "Update Loop submodule with Pebble integration"

# Push both
git push origin feature/pebble-integration
cd Loop
git push origin feature/pebble-integration
cd ..
```

#### Step 3: Add PebbleService to Xcode Project

**This is the critical step for browser builds!**

Browser builds use the Xcode project file (`.xcodeproj`) to know what to compile. If PebbleService files aren't in the project, they won't be compiled.

**Option A: Using Xcode (Recommended)**
```bash
# Open on Mac
open LoopWorkspace/Loop.xcodeproj

# In Xcode:
# 1. Right-click on Loop target
# 2. Add Files to "Loop"
# 3. Select all files in PebbleService/
# 4. Check "Copy items if needed"
# 5. Ensure "Loop" target is selected
# 6. Click "Add"

# Commit the .xcodeproj changes
git add Loop.xcodeproj
git commit -m "Add PebbleService files to Xcode project"
git push
```

**Option B: Manual .pbxproj Edit (Advanced)**
If you don't have access to a Mac, you'll need to manually edit the `.pbxproj` file to add PebbleService files. This is complex and error-prone.

#### Step 4: Verify GitHub Actions Workflow

Check that your `.github/workflows/` directory has the build workflow:

```bash
ls -la .github/workflows/
# Should contain: build.yml or similar
```

The workflow should already handle building the Loop app - no changes needed unless you have special requirements.

---

## 📋 Browser Build Setup Steps

### Prerequisites

- ✅ GitHub account (you have this)
- ✅ Apple Developer account ($99/year)
- ✅ LoopWorkspace fork with Pebble integration
- ✅ Compatible iPhone, CGM, and pump

### Initial Setup (First Time Only)

Follow the official LoopDocs browser build guide:

1. **[Collect Secrets](https://loopkit.github.io/loopdocs/browser/secrets/)**
   - Apple Developer credentials
   - API keys for FastLane
   - GitHub repository secrets

2. **[Prepare Fork](https://loopkit.github.io/loopdocs/browser/prepare-fork/)**
   - Your fork should already be ready
   - Ensure `feature/pebble-integration` branch is up-to-date

3. **[Prepare Identifiers](https://loopkit.github.io/loopdocs/browser/identifiers/)**
   - Create App ID in Apple Developer portal
   - Configure bundle identifier

4. **[Prepare App](https://loopkit.github.io/loopdocs/browser/prepare-app/)**
   - Set up provisioning profiles
   - Configure signing certificates

5. **[Prepare TestFlight Group](https://loopkit.github.io/loopdocs/browser/tf-users/)**
   - Add yourself as tester
   - Set up internal testing group

6. **[Build the Loop App](https://loopkit.github.io/loopdocs/browser/build-yml/)**
   - Trigger first build
   - Wait ~30 minutes
   - Check for errors

### For Your Pebble Integration

**Additional Step:** Ensure branch selection is correct

In your GitHub Actions workflow, make sure it's building from `feature/pebble-integration`:

```yaml
# In .github/workflows/build.yml
on:
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * 0'  # Weekly builds

defaults:
  run:
    shell: bash
    
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: recursive
          ref: feature/pebble-integration  # ← Ensure this points to your branch
```

---

## 🔍 Troubleshooting Browser Builds

### Common Issue: "No such module 'PebbleService'"

**Cause:** PebbleService files not added to Xcode project target

**Solution:**
1. Open `Loop.xcodeproj` in Xcode
2. Ensure all PebbleService Swift files are in the Loop target
3. Commit and push `.xcodeproj` changes
4. Rebuild

### Common Issue: Submodule Not Updating

**Cause:** GitHub Actions not pulling latest submodule changes

**Solution:**
```yaml
# In build.yml, ensure:
- uses: actions/checkout@v3
  with:
    submodules: recursive  # This is critical!
    fetch-depth: 0
```

### Common Issue: Build Fails on Import

**Cause:** PebbleService not in compilation target

**Debug:**
```bash
# Check GitHub Actions logs for:
# "warning: no files found matching 'PebbleService'"

# Verify files are in .xcodeproj:
grep -i "PebbleManager.swift" Loop.xcodeproj/project.pbxproj
# Should show file references
```

---

## 📱 After Successful Build

### Install via TestFlight

1. Wait for build to complete (~30 min)
2. Check email from App Store Connect
3. Open TestFlight app on iPhone
4. Install your Loop build
5. Launch and verify:
   - Settings → Pebble Smartwatch section exists
   - Can toggle Pebble connection on/off
   - No crash on launch

### Verify Pebble Integration Works

1. **Enable Pebble in Settings**
   - Open Loop app
   - Go to Settings
   - Find "Pebble Smartwatch" section
   - Tap to enable (should show "Connected")

2. **Test HTTP Server**
   - From iPhone (same network), try:
   ```bash
   curl http://YOUR_IPHONE_IP:8080/api/all
   ```
   - Should return JSON with CGM/pump data

3. **Install Pebble Watch App**
   - Use existing `.pbw` files or build new one
   - Deploy to Pebble watch
   - Verify Bluetooth connection

---

## 🔄 Updating Your Build

### When to Rebuild

- After code changes (new features, bug fixes)
- Monthly (LoopKit releases updates)
- When iOS updates break compatibility
- TestFlight build expires (90 days)

### How to Update

1. **Make code changes** (if needed)
2. **Commit and push** to `feature/pebble-integration`
3. **Trigger new build:**
   - Go to GitHub repository
   - Click "Actions" tab
   - Select "Build Loop" workflow
   - Click "Run workflow"
   - Choose `feature/pebble-integration` branch
   - Click "Run workflow"

4. **Wait ~30 minutes**
5. **Install new build from TestFlight**

---

## 🎯 Specific Notes for Pebble Integration

### What Browser Build Does Differently

| Aspect | Mac Build (Xcode) | Browser Build (GitHub Actions) |
|-|-|-|
| **Build Location** | Your Mac | Cloud (macOS runner) |
| **File Access** | Full filesystem | Git repository only |
| **Debugging** | Xcode debugger | Logs only |
| **Iteration Speed** | Fast (minutes) | Slower (~30 min per build) |
| **PebbleService** | Easy to add | Must be in Git + .xcodeproj |

### Best Practices for Pebble Development

1. **Test Locally First** (if you have Mac access)
   - Build on Mac to verify code works
   - Debug issues before cloud build

2. **Small, Incremental Changes**
   - Commit frequently
   - Each commit should be a working state
   - Easier to debug if build fails

3. **Document Everything**
   - Comment code thoroughly
   - Update README with setup steps
   - Keep changelog of modifications

4. **Keep Branch Organized**
   - `main` = stable, working version
   - `feature/pebble-integration` = active development
   - Create feature branches for big changes

---

## 📚 Resources

### Official Documentation
- [Browser Build Overview](https://loopkit.github.io/loopdocs/browser/bb-overview/)
- [Browser Build Errors](https://loopkit.github.io/loopdocs/browser/bb-errors/)
- [Custom Edits with Browser](https://loopkit.github.io/loopdocs/browser/edit-browser/)

### Your Project Files
- `PROJECTS/pebble-integration-status.md` - Milestone tracking
- `PEBBLE_INTEGRATION_GUIDE.md` - Technical integration guide
- `IMPLEMENTATION_SUMMARY_2026-03-26.md` - What was implemented

### GitHub Repos
- Your fork: `github.com/MinimusClawdius/LoopWorkspace`
- Upstream: `github.com/LoopKit/Loop`
- Pebble reference: `github.com/nightscout/cgm-pebble`

---

## ✅ Pre-Flight Checklist

Before triggering browser build:

- [ ] All PebbleService files committed to Git
- [ ] PebbleService added to Loop.xcodeproj target
- [ ] Loop submodule updated and pushed
- [ ] `.github/workflows/build.yml` points to correct branch
- [ ] GitHub Secrets configured (Apple credentials, etc.)
- [ ] TestFlight group set up with your Apple ID
- [ ] `feature/pebble-integration` branch is up-to-date on GitHub

---

## 🚀 Ready to Build?

Once everything is set up:

1. Go to your GitHub repository
2. Click **Actions** → **Build Loop**
3. Click **Run workflow**
4. Select `feature/pebble-integration` branch
5. Click **Run workflow**
6. Wait ~30 minutes
7. Check **TestFlight** app on iPhone

---

**Need help?** If build fails, check the Actions logs and provide the error message. Common issues are documented in [Browser Build Errors](https://loopkit.github.io/loopdocs/browser/bb-errors/).

---

**Created:** 2026-03-26  
**For:** Browser Build deployment with PebbleService integration  
**Status:** Ready for first build
