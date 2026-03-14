# Pebble Smartwatch Integration for Loop

## Overview

This integration adds Pebble smartwatch support to Loop, providing real-time blood glucose monitoring, pump status, and loop control status on your wrist — completely off-grid with no cloud dependency.

## Architecture

```
┌─────────────────┐     Bluetooth      ┌─────────────────┐
│   Pebble Watch  │◄──────────────────►│     iPhone      │
│                 │                     │                 │
│  - CGM Display  │                     │  Local HTTP     │
│  - Trend Arrow  │                     │  Server (:8080) │
│  - IOB/COB      │                     │       │         │
│  - Loop Status  │                     │       ▼         │
│  - Alerts       │                     │   LoopKit Data  │
└─────────────────┘                     └─────────────────┘
```

### Communication Flow

1. **Loop** collects CGM/pump data via LoopKit
2. **PebbleManager** receives WatchContext updates
3. **LocalAPIServer** exposes data on `http://127.0.0.1:8080`
4. **Pebble** connects via Bluetooth, fetches data from localhost
5. **Watch app** displays glucose, trends, IOB, and alerts

## Components

### iOS (PebbleService/)

| File | Description |
|------|-------------|
| `PebbleManager.swift` | Main interface, starts/stops integration |
| `LocalAPIServer.swift` | HTTP server on localhost:8080 |
| `LoopDataBridge.swift` | Converts LoopKit data to JSON |

### Pebble Watch App (pebble/)

| File | Description |
|------|-------------|
| `src/main.c` | Watch app UI and logic |
| `src/js/pebble-js-app.js` | Fetches data from iPhone API |
| `appinfo.json` | App configuration |

## API Endpoints

All endpoints are on `http://127.0.0.1:8080` (localhost only).

### GET /api/cgm
Blood glucose data.

```json
{
  "glucose": 120.5,
  "unit": "mg/dL",
  "trend": "→",
  "date": "2026-03-14T12:00:00Z",
  "isStale": false
}
```

### GET /api/pump
Insulin pump status.

```json
{
  "reservoir": 150.0,
  "reservoirPercent": 75.0,
  "battery": 85.0
}
```

### GET /api/loop
Loop control status.

```json
{
  "isClosedLoop": true,
  "lastRun": "2026-03-14T12:00:00Z",
  "iob": 2.5,
  "cob": 15.0,
  "recommendedBolus": 0.5,
  "predictedGlucose": [120, 125, 130, 128]
}
```

### GET /api/all
All data combined (used by Pebble).

### GET /health
Health check endpoint.

## Integration Steps

### 1. Add PebbleService to Loop

In Xcode or your build configuration:

1. Add `PebbleService/` directory to your project
2. Import `PebbleManager` in your LoopDataManager
3. Start PebbleManager when Loop starts

```swift
// In LoopDataManager or similar
import PebbleService

// Start Pebble integration
PebbleManager.shared.start()

// When WatchContext updates
func notifyPebble(context: WatchContext) {
    PebbleManager.shared.updateContext(context)
}
```

### 2. Build Pebble App

Using the Pebble SDK:

```bash
cd pebble/
pebble build
pebble install --phone <your-phone-ip>
```

### 3. Browser Build Integration

For browser builds (https://www.loopnlearn.org/bb-rebuild-using-your-phone/):

1. Add `PebbleService/` to your Loop fork
2. Include the files in your Xcode project configuration
3. The local HTTP server will start automatically when Loop runs

## Watch Display

```
┌─────────────────┐
│      12:30      │  ← Time
│                 │
│      120        │  ← Glucose (large)
│       →         │  ← Trend arrow
│                 │
│   IOB: 2.5U     │  ← Insulin on board
│   Loop: ON      │  ← Loop status
│                 │
└─────────────────┘
```

### Color Coding (Pebble Color)

- **Green**: Glucose in range (70-180 mg/dL)
- **Red**: Low glucose (<70 mg/dL)
- **Orange**: High glucose (>180 mg/dL)

### Alerts

- **Double pulse vibration**: Low glucose alert
- **Single pulse vibration**: High glucose alert
- Alerts limited to once every 15 minutes

## Off-Grid Operation

This integration works completely offline:

- ✅ No internet required
- ✅ No cloud services
- ✅ Local HTTP server on iPhone
- ✅ Bluetooth connection to Pebble
- ✅ Works in airplane mode (with Bluetooth enabled)

## Requirements

- iPhone with Loop installed
- Pebble smartwatch (any model: Aplite, Basalt, Chalk, Diorite, Emery)
- Pebble app installed on iPhone
- Bluetooth enabled

## Security

- HTTP server binds to **127.0.0.1 only** (localhost)
- No external network access
- No data leaves the device
- No authentication needed (local only)

## Troubleshooting

### Watch shows "Loading..."
- Ensure Loop is running on iPhone
- Check Bluetooth connection
- Restart Pebble app

### Watch shows timeout/error
- Verify Loop is running and PebbleManager is started
- Check that port 8080 is not in use by another app
- Restart both apps

### Data not updating
- Check Loop is receiving CGM data
- Verify PebbleManager.updateContext() is being called
- Check iPhone logs for "[PebbleService]" messages

## Development

### Testing the API

On your iPhone (with Loop running):

```bash
# From a terminal on the same network
curl http://localhost:8080/api/all
curl http://localhost:8080/health
```

### Adding Features

To add new data fields:

1. Add to `LoopDataBridge.swift` 
2. Update `allDataJSON()` method
3. Update `pebble-js-app.js` to parse new field
4. Add `AppMessage` key in `main.c`
5. Update UI in watch app

## License

This integration follows the same license as LoopKit (MIT).

## Credits

- LoopKit team for the amazing Loop app
- Rebble.io for keeping Pebble alive
- Pebble SDK community
