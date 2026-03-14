# LoopWorkspace with Pebble Smartwatch Support

This fork of LoopWorkspace adds **Pebble smartwatch integration** with off-grid, no-cloud communication. Monitor your glucose, request bolus delivery, and log carbs directly from your Pebble watch.

## Features

### Pebble Smartwatch Integration
- ✅ Blood glucose display with trend arrows
- ✅ IOB (insulin on board) and COB (carbs on board)
- ✅ Loop status monitoring
- ✅ Pump battery and reservoir levels
- ✅ Low/high glucose alerts
- ✅ Bolus requests (requires iPhone confirmation)
- ✅ Carb entry (requires iPhone confirmation)
- ✅ Off-grid operation (Bluetooth only, no internet required)
- ✅ Browser build compatible

### Safety First
- **All commands require explicit confirmation on iPhone before execution**
- Configurable safety limits (max bolus, max carbs)
- Commands expire after 5 minutes if not confirmed
- Local HTTP server on iPhone only (no external network access)

## Build Instructions

### GitHub Build (Browser)

The GitHub Build Instructions are at this [link](fastlane/testflight.md) and further expanded in [LoopDocs: Browser Build](https://loopkit.github.io/loopdocs/gh-actions/gh-overview/).

### Mac/Xcode Build

The rest of this README contains information needed for Mac/Xcode build. Additional instructions are found in [LoopDocs: Mac/Xcode Build](https://loopkit.github.io/loopdocs/build/overview/).

#### Clone

This repository uses git submodules to pull in the various workspace dependencies.

To clone this repo:

```bash
git clone --recurse-submodules https://github.com/MinimusClawdius/LoopWorkspace
```

#### Open

Change to the cloned directory and open the workspace in Xcode:

```bash
cd LoopWorkspace
xed .
```

#### Input your development team

You should be able to build to a simulator without changing anything. But if you wish to build to a real device, you'll need a developer account, and you'll need to tell Xcode about your team id, which you can find at https://developer.apple.com/.

Select the LoopConfigOverride file in Xcode's project navigator, uncomment the `LOOP_DEVELOPMENT_TEAM`, and replace the existing team id with your own id.

#### Build

Select the "LoopWorkspace" scheme (not the "Loop" scheme) and Build, Run, or Test.

## Pebble Smartwatch Setup

### Prerequisites

1. **Pebble Smartwatch** (any model: Pebble, Pebble Time, Pebble Steel, Pebble 2, etc.)
2. **Pebble App** installed on iPhone ([Rebble](https://rebble.io/howto/))
3. **Pebble SDK** (for building the watch app) - [Install Guide](https://developer.rebble.io/developer.pebble.com/sdk/index.html)

### Installing the Pebble Watch App

#### Option 1: Using Pebble SDK (Recommended)

1. Install the Pebble SDK:
   ```bash
   # macOS
   brew install pebble-sdk
   
   # Linux
   pip install pebble-sdk
   ```

2. Build the watch app:
   ```bash
   cd pebble/
   pebble build
   ```

3. Install on your Pebble:
   ```bash
   # Connect via Bluetooth to your phone first
   pebble install --phone <your-phone-ip>
   
   # Or install via cloud (Rebble)
   pebble install --cloudpebble
   ```

#### Option 2: Using Rebble Developer Portal

1. Go to [CloudPebble](https://cloudpebble.net/)
2. Create new project "Loop CGM"
3. Upload the `pebble/` directory contents
4. Build and install directly to your watch

### Configuring the iOS App

1. **Add PebbleService to your Loop build:**
   - In Xcode, add the `PebbleService/` folder to your project
   - Ensure all Swift files are included in the target

2. **Enable Pebble integration in Loop:**
   
   In your `AppDelegate.swift` or main Loop initialization:
   ```swift
   import PebbleService
   
   // Start Pebble integration
   PebbleManager.shared.start()
   
   // Configure safety limits
   PebbleManager.shared.maxBolus = 10.0  // Maximum 10U bolus
   PebbleManager.shared.maxCarbs = 200.0 // Maximum 200g carbs
   ```

3. **Add confirmation UI:**
   
   Add the confirmation view to your app:
   ```swift
   struct ContentView: View {
       var body: some View {
           TabView {
               // ... your existing views
               
               PebbleCommandConfirmationView()
                   .tabItem {
                       Label("Pebble", systemImage: "applewatch")
                   }
           }
       }
   }
   ```

4. **Connect to LoopDataManager:**
   
   When WatchContext updates, notify Pebble:
   ```swift
   func notifyPebble(context: WatchContext) {
       PebbleManager.shared.updateContext(context)
   }
   ```

### Browser Build Integration

For browser builds without Xcode:

1. **Add PebbleService to your fork:**
   - Copy `PebbleService/` directory to your Loop fork
   - The files will be included automatically

2. **Configure in LoopConfigOverride.xcconfig:**
   ```
   // Enable Pebble integration
   LOOP_PEBBLE_ENABLED = YES
   ```

3. **Build using GitHub Actions:**
   - The standard browser build process will include PebbleService
   - No additional configuration needed

### API Endpoints (Local)

The iOS app runs a local HTTP server on `localhost:8080`:

- `GET /api/cgm` - Blood glucose data
- `GET /api/pump` - Pump status
- `GET /api/loop` - Loop status
- `GET /api/all` - All data combined
- `POST /api/bolus` - Request bolus (requires confirmation)
- `POST /api/carbs` - Log carbs (requires confirmation)

### Troubleshooting

#### Pebble not connecting
- Ensure Bluetooth is enabled on both devices
- Check that Pebble app is running on iPhone
- Restart the Pebble watch app

#### Commands not appearing on iPhone
- Verify PebbleManager is started in Loop
- Check that confirmation delegate is set
- Look for "[PebbleService]" logs in Xcode

#### Build errors
- Ensure all PebbleService files are included in the target
- Check that LoopKit and HealthKit frameworks are linked
- Verify iOS deployment target is 15.0 or later

## Documentation

- [Pebble Integration Guide](Documentation/pebble-integration.md) - Detailed technical documentation
- [API Reference](Documentation/pebble-integration.md#api-endpoints) - Complete API documentation
- [Safety Features](Documentation/pebble-integration.md#safety-ios-confirmation-required) - Safety system details

## License

This project follows the same license as LoopKit (MIT).

## Credits

- [LoopKit](https://github.com/LoopKit) - Original Loop app
- [Rebble](https://rebble.io/) - Keeping Pebble alive
- [Pebble Developer](https://developer.rebble.io/) - Pebble SDK and documentation

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## Support

For support, please open an issue on GitHub or visit the [LoopDocs community](https://loopkit.github.io/loopdocs/).
