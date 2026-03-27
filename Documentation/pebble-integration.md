# Pebble Smartwatch Integration for Loop

## Overview

This integration adds Pebble smartwatch support to Loop with **off-grid communication** and **iOS-confirmed commands** for bolus delivery and carb entry.

## Features

### Read-Only Monitoring
- ✅ Blood glucose display with trend arrows
- ✅ IOB (insulin on board) and COB (carbs on board)
- ✅ Loop status (ON/OFF)
- ✅ Pump battery and reservoir levels
- ✅ Low/high glucose alerts with vibration

### Commands (Require iOS Confirmation)
- ✅ **Bolus request** — adjustable amount via watch buttons
- ✅ **Carb entry** — adjustable grams with absorption time
- ⚠️ **All commands require explicit confirmation on iPhone before execution**

## Architecture

```
┌─────────────────┐     Bluetooth      ┌─────────────────┐
│   Pebble Watch  │◄──────────────────►│     iPhone      │
│                 │                     │                 │
│  - CGM Display  │  GET /api/all      │  Local HTTP     │
│  - Bolus Entry  │──────────────────►│  Server (:8080) │
│  - Carb Entry   │  POST /api/bolus   │       │         │
│                 │──────────────────►│       ▼         │
│                 │  POST /api/carbs   │   LoopKit Data  │
│                 │──────────────────►│       │         │
│                 │                     │       ▼         │
│                 │◄─────────────────│  iOS Confirm UI  │
│  "Confirm on    │  Command Status    │  (Accept/Reject)│
│   iPhone"       │                     │                 │
└─────────────────┘                     └─────────────────┘
```

## Safety: iOS Confirmation Required

**All commands from Pebble require explicit user confirmation on the iPhone before execution.**

This is a critical safety feature:
1. User sends command from Pebble (e.g., "Bolus 1.5U")
2. Command is **queued** on iPhone with status "pending_confirmation"
3. iPhone shows notification/alert with Accept/Reject buttons
4. Only after user taps "Confirm" does the command execute
5. Commands **expire after 5 minutes** if not confirmed

### Safety Limits
- **Maximum bolus**: 10.0U (configurable)
- **Maximum carbs**: 200g per entry
- **Bolus precision**: 0.05U increments
- **Carb precision**: 5g increments

## Components

### iOS (PebbleService/)

| File | Description |
|------|-------------|
| `PebbleManager.swift` | Main interface, starts/stops integration |
| `LocalAPIServer.swift` | HTTP server on localhost:8080 |
| `LoopDataBridge.swift` | Converts LoopKit data to JSON |
| `PebbleCommandManager.swift` | Command queue with confirmation flow |
| `PebbleCommandConfirmationView.swift` | SwiftUI UI for confirming commands |

### Pebble Watch App (pebble/)

| File | Description |
|------|-------------|
| `src/main.c` | Watch app UI, bolus/carb entry screens |
| `src/js/pebble-js-app.js` | API communication, command sending |
| `appinfo.json` | App configuration |

## API Endpoints

All endpoints are on `http://127.0.0.1:8080` (localhost only).

### Read Endpoints (GET)

#### GET /api/cgm
Blood glucose data.

#### GET /api/pump
Insulin pump status.

#### GET /api/loop
Loop control status.

#### GET /api/all
All data combined (used by Pebble).

#### GET /api/commands/pending
Pending commands awaiting confirmation.

### Command Endpoints (POST)

#### POST /api/bolus
Queue a bolus request (requires iOS confirmation).

**Request:**
```json
{"units": 1.5}
```

**Response (202 Accepted):**
```json
{
  "status": "pending_confirmation",
  "commandId": "uuid-here",
  "message": "Confirm 1.50U bolus on iPhone",
  "type": "bolus"
}
```

#### POST /api/carbs
Queue a carb entry (requires iOS confirmation).

**Request:**
```json
{"grams": 30, "absorptionHours": 3}
```

**Response (202 Accepted):**
```json
{
  "status": "pending_confirmation",
  "commandId": "uuid-here",
  "message": "Confirm 30g carbs on iPhone",
  "type": "carbEntry"
}
```

#### POST /api/command/confirm
Confirm a pending command (called from iOS UI).

**Request:**
```json
{"commandId": "uuid-here"}
```

#### POST /api/command/reject
Reject a pending command (called from iOS UI).

**Request:**
```json
{"commandId": "uuid-here"}
```

## Pebble Watch UI

### Main Screen
```
┌─────────────────┐
│      12:30      │  ← Time
│                 │
│      120        │  ← Glucose (color-coded)
│       →         │  ← Trend arrow
│                 │
│   IOB: 2.5U     │  ← Insulin on board
│   Loop: ON      │  ← Loop status
│                 │
│ SELECT=actions  │  ← Hint
└─────────────────┘
```

### Command Menu
Press SELECT to open:
- **Request Bolus** — opens bolus entry screen
- **Log Carbs** — opens carb entry screen

### Bolus Entry Screen
```
┌─────────────────┐
│  Request Bolus  │
│                 │
│     1.50 U      │  ← Use ▲▼ to adjust (0.05U steps)
│                 │
│  ▲▼ to adjust   │
│  SELECT to send │
│  Confirm on     │
│  iPhone         │
└─────────────────┘
```

### Carb Entry Screen
```
┌─────────────────┐
│   Log Carbs     │
│                 │
│      30 g       │  ← Use ▲▼ to adjust (5g steps)
│                 │
│  ▲▼ to adjust   │
│  SELECT to send │
│  Confirm on     │
│  iPhone         │
└─────────────────┘
```

### Confirmation Sent Screen
```
┌─────────────────┐
│  Request Sent!  │
│                 │
│  Check your     │
│  iPhone to      │
│  confirm.       │
│                 │
└─────────────────┘
(Auto-dismisses after 3 seconds)
```

## Integration Steps

### 1. Add PebbleService to Loop

Add `PebbleService/` directory to your Xcode project and import:

```swift
import PebbleService

// In AppDelegate or LoopDataManager
PebbleManager.shared.start()

// Set safety limits
PebbleManager.shared.maxBolus = 10.0
PebbleManager.shared.maxCarbs = 200.0

// Set confirmation delegate (for showing UI)
PebbleManager.shared.confirmationDelegate = self
```

### 2. Implement Confirmation UI

Use the provided `PebbleCommandConfirmationView`:

```swift
struct ContentView: View {
    var body: some View {
        TabView {
            // ... your existing views
            
            PebbleCommandConfirmationView()
                .tabItem {
                    Label("Pebble", systemImage: "applewatch")
                }
                .badge(PebbleCommandManager.shared.getPendingCommands().count)
        }
    }
}
```

Or implement custom UI:

```swift
extension YourViewController: PebbleCommandConfirmationDelegate {
    func pendingCommandRequiresConfirmation(_ command: PebbleCommand) {
        let alert = UIAlertController(
            title: "Pebble Request",
            message: command.confirmationMessage,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Reject", style: .destructive) { _ in
            PebbleCommandManager.shared.rejectCommand(command.id)
        })
        
        alert.addAction(UIAlertAction(title: "Confirm", style: .default) { _ in
            PebbleCommandManager.shared.confirmCommand(command.id, 
                                                       doseStore: self.doseStore,
                                                       carbStore: self.carbStore)
        })
        
        present(alert, animated: true)
    }
}
```

### 3. Build Pebble App

```bash
cd pebble/
pebble build
pebble install --phone <your-phone-ip>
```

### 4. Browser Build Integration

For browser builds (https://www.loopnlearn.org/bb-rebuild-using-your-phone/):

1. Add `PebbleService/` to your Loop fork
2. Include files in Xcode project configuration
3. Local HTTP server starts automatically when Loop runs

## Off-Grid Operation

- ✅ No internet required
- ✅ No cloud services
- ✅ Local HTTP server on iPhone
- ✅ Bluetooth connection to Pebble
- ✅ Works in airplane mode (with Bluetooth enabled)

## Security

- HTTP server binds to **127.0.0.1 only** (localhost)
- No external network access
- No data leaves the device
- All commands require **explicit iOS confirmation**
- Commands **expire after 5 minutes** if not confirmed

## Troubleshooting

### Watch shows "Loading..."
- Ensure Loop is running on iPhone
- Check Bluetooth connection
- Restart Pebble app

### Commands not appearing on iPhone
- Verify PebbleManager is started
- Check that confirmation delegate is set
- Look for "[PebbleService]" logs

### Command rejected automatically
- Check if command exceeds safety limits
- Verify command hasn't expired (5 min timeout)

## Development

### Testing the API

```bash
# Test data endpoints
curl http://localhost:8080/api/all

# Test bolus request
curl -X POST http://localhost:8080/api/bolus \
  -H "Content-Type: application/json" \
  -d '{"units": 1.5}'

# Test carb entry
curl -X POST http://localhost:8080/api/carbs \
  -H "Content-Type: application/json" \
  -d '{"grams": 30}'
```

## License

This integration follows the same license as LoopKit (MIT).

## Credits

- LoopKit team for the amazing Loop app
- Rebble.io for keeping Pebble alive
- Pebble SDK community
