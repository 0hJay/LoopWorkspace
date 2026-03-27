# PebbleService Integration Guide for LoopWorkspace

## Current State Assessment

### ✅ What Exists
- `PebbleService/` folder with complete implementation:
  - `PebbleManager.swift` - Main orchestration
  - `PebbleCommandManager.swift` - Command queue with iOS confirmation
  - `LocalAPIServer.swift` - HTTP server on localhost:8080
  - `LoopDataBridge.swift` - Data conversion to JSON
  - `PebbleCommandConfirmationView.swift` - SwiftUI confirmation UI

### ❌ What's Missing
- PebbleService NOT added to Xcode project
- No import statements in Loop app
- No initialization in LoopAppManager
- No settings UI toggle

---

## Integration Steps

### Step 1: Add PebbleService Files to Xcode Project

**Manual Steps Required:**
```bash
# Open LoopWorkspace.xcodeproj in Xcode
# Drag PebbleService/ folder into project
# Check "Copy items if needed"
# Ensure target is "Loop" (main app)
```

**Alternative: Command Line**
```bash
cd /workspace/LoopWorkspace
# Need to edit .xcodeproj/project.pbxproj manually
# Or use xcodebuild commands
```

### Step 2: Import PebbleService in LoopAppManager

**File:** `Loop/Loop/Managers/LoopAppManager.swift`

**Add at top:**
```swift
import PebbleService
```

**Add property after other managers:**
```swift
private var pebbleManager: PebbleManager!
```

**Initialize in `launchManagers()`:**
```swift
func launchManagers() {
    // ... existing code ...
    
    // Initialize Pebble integration
    pebbleManager = PebbleManager.shared
    pebbleManager.maxBolus = 10.0  // Safety limit
    pebbleManager.maxCarbs = 200.0 // Safety limit
    pebbleManager.confirmationDelegate = self
    
    // Don't start automatically - wait for user toggle in settings
    // pebbleManager.start()
}
```

### Step 3: Conform to PebbleCommandConfirmationDelegate

**Add conformance to LoopAppManager:**
```swift
extension LoopAppManager: PebbleCommandConfirmationDelegate {
    func pendingCommandRequiresConfirmation(_ command: PebbleCommand) {
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Pebble Request",
            message: command.confirmationMessage,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Reject", style: .destructive) { [weak self] _ in
            self?.pebbleManager.commandManager.rejectCommand(command.id)
        })
        
        alert.addAction(UIAlertAction(title: "Confirm", style: .default) { [weak self] _ in
            self?.pebbleManager.commandManager.confirmCommand(
                command.id,
                doseStore: self?.deviceDataManager.doseStore,
                carbStore: self?.deviceDataManager.carbStore
            )
        })
        
        // Present on main window
        if let window = windowProvider?.window,
           let rootVC = window.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
    
    func commandExecuted(_ command: PebbleCommand) {
        log.info("Pebble command executed: \(command.type.rawValue)")
    }
    
    func commandFailed(_ command: PebbleCommand, error: String) {
        log.error("Pebble command failed: \(error)")
    }
}
```

### Step 4: Connect to Loop Data Updates

**Find where WatchContext updates happen and add:**

In `DeviceDataManager` or wherever CGM data is updated:
```swift
import PebbleService

// When glucose updates:
PebbleManager.shared.updateGlucose(
    value: glucoseValue,
    unit: "mg/dL",
    trend: trendString,
    date: date
)

// When insulin updates:
PebbleManager.shared.updateInsulin(
    iob: insulinOnBoard,
    cob: carbsOnBoard,
    reservoir: reservoirUnits,
    reservoirPercent: batteryPercent
)

// When loop runs:
PebbleManager.shared.updateLoopStatus(
    isClosedLoop: automaticDosingEnabled,
    lastRun: lastLoopDate,
    recommendedBolus: suggestedBolus,
    predicted: predictedGlucoseArray
)
```

### Step 5: Add Settings Toggle

**Option A: Add to Existing Settings View**

Find settings view controller and add new section:
```swift
import PebbleService

// In SettingsViewController or equivalent
private func addPebbleSection() {
    let pebbleSection = SettingsSection(
        title: "Pebble Smartwatch",
        items: [
            SettingItem(
                title: "Enable Pebble Connection",
                subtitle: pebbleManager.isRunning ? "Connected" : "Disconnected",
                type: .toggle(isOn: pebbleManager.isRunning) { [weak self] isOn in
                    if isOn {
                        self?.pebbleManager.start()
                    } else {
                        self?.pebbleManager.stop()
                    }
                }
            )
        ]
    )
    sections.append(pebbleSection)
}
```

**Option B: Create Dedicated PebbleSettingsView**

Create new SwiftUI view:
```swift
import SwiftUI
import PebbleService

struct PebbleSettingsView: View {
    @State private var isEnabled = false
    
    var body: some View {
        Form {
            Toggle("Enable Pebble Connection", isOn: $isEnabled)
                .onChange(of: isEnabled) { newValue in
                    if newValue {
                        PebbleManager.shared.start()
                    } else {
                        PebbleManager.shared.stop()
                    }
                }
            
            Section(header: Text("Status")) {
                Text(PebbleManager.shared.isRunning ? "Connected" : "Disconnected")
                Text("API: http://127.0.0.1:8080")
            }
            
            Section(header: Text("Safety Limits")) {
                HStack {
                    Text("Max Bolus:")
                    TextField("", value: $maxBolus, format: .number)
                    Text("units")
                }
                
                HStack {
                    Text("Max Carbs:")
                    TextField("", value: $maxCarbs, format: .number)
                    Text("grams")
                }
            }
        }
        .navigationTitle("Pebble")
    }
    
    @State private var maxBolus: Double = 10.0
    @State private var maxCarbs: Double = 200.0
}
```

---

## Testing Checklist

After integration:

- [ ] Build succeeds in Xcode
- [ ] PebbleManager starts without errors
- [ ] Local HTTP server listens on port 8080
- [ ] Can curl `http://localhost:8080/api/all` from iPhone
- [ ] Pebble watch app can connect via Bluetooth
- [ ] CGM data appears on Pebble
- [ ] Bolus commands require iOS confirmation
- [ ] Settings toggle works

---

## Troubleshooting

### Build Errors
```
error: no such module 'PebbleService'
```
**Fix:** Ensure PebbleService files are added to Loop target in Xcode

### Port Already in Use
```
error: bind: Address already in use
```
**Fix:** Check if another app is using port 8080, change port in LocalAPIServer

### Bluetooth Not Working
- Ensure Bluetooth enabled in Settings → Bluetooth
- Check Pebble app has Bluetooth permissions
- Verify phone and watch are paired

---

## Next Steps After Integration

1. **Test with real Pebble device**
2. **Add to settings menu**
3. **Document for users**
4. **Deploy to TestFlight**

---

**Created:** 2026-03-26  
**Status:** Ready for implementation
