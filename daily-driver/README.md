# Daily Driver

A full-screen data field for everyday riding on the **Garmin Edge 1030 Plus**. Displays all essential ride metrics at a glance with Strava-inspired zone visualization.

## Screen Layout

The screen is organized top to bottom with zone bars on each side:

### Zone Bars (left and right edges)

Two vertical colored bars running the full height of the screen:

- **Left bar** — Power zones (7 zones, purple gradient, Strava-style)
- **Right bar** — HR zones (5 zones, red gradient, Strava-style)

Zone heights are weighted so the zones where you ride most (Z2-Z4) get more visual space. The active zone is wider with smooth tapered transitions to neighboring zones. Colors adapt to light/dark mode.

**Markers on the bars:**

| Marker | Meaning |
|--------|---------|
| Triangle (pointing inward) | Current value (5s power / 3s HR) |
| Horizontal line | Norm. Power (power bar) / Average HR (HR bar) |
| Star | FTP threshold (power bar) / LT threshold (HR bar) |

### Speed Gauge (top)

A semicircular arc designed to instantly show whether you're above or below your target average speed. Your ride average sits at the top center — if the dot is left of center, you're pulling your average down; right of center, you're pulling it up. No need to compare numbers while riding.

The scale is logarithmic with more resolution near your average speed, where it matters most. Zero on the left, top speed on the right. Average speed is displayed smaller above the large current speed number.

### Data Panel (center, 5 rows)

| Row | Left | Right |
|-----|------|-------|
| 1 | **Power** (5s avg, large) | **HR** (3s avg, large) |
| 2 | Avg Power | Avg HR |
| 3 | Norm. Power | Cadence |
| 4 | Distance (km) | Elevation gain (m) |
| 5 | Ride time (elapsed) | Time of day |

## Norm. Power

Calculated in real-time: 30-second rolling average of power, raised to the 4th power, averaged, then 4th root. It represents the actual physiological cost of your ride — always >= average power. The bigger the gap, the more variable your effort. Needs 30 seconds of data before showing a value.

## Zones

- HR zones (5) and power zones (7) are loaded from your Garmin device profile
- If not configured, defaults are calculated from your FTP
- Zone 1 lower bound uses your resting heart rate

## Light/Dark Mode

Fully supports both modes. All text, markers, separators, and zone colors automatically adjust for readability.

## Building

### Requirements

- [Connect IQ SDK 9.1.0](https://developer.garmin.com/connect-iq/sdk/)
- A developer key (`developer_key.der` in repo root)

### Build & Run

```bash
# Start the simulator
open "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b/bin/ConnectIQ.app"

# Build (from repo root)
monkeyc -d edge1030plus -o daily-driver/build/DailyDriver.prg -f daily-driver/monkey.jungle -y developer_key.der -w

# Deploy to simulator
monkeydo daily-driver/build/DailyDriver.prg edge1030plus
```

### Install on Device

1. Connect your Edge 1030 Plus via USB
2. Copy `daily-driver/build/DailyDriver.prg` to `/Volumes/GARMIN/GARMIN/APPS/`
3. Safely eject the device
4. On the Edge: Activity Profiles > Data Screens > add "Daily Driver" as a data field

## Known Limitations

- **Simulator**: Uses random sensor data — HR/power zones will look unreasonable. Real device uses your actual zones and sensor data.
- **Mid-session reload**: If you replace the `.prg` during an active session, accumulated values (distance, elevation, avg speed) won't recover. This is a Connect IQ limitation — not an issue during normal rides.
- **Norm. Power delay**: Needs 30 seconds of power data before showing a value.
