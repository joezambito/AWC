# AWC – Setup Guide

This guide covers everything needed to build and run AWC on a physical
device or the simulator, including Interactive Brokers TWS network
configuration.

---

## 1. Prerequisites

| Tool | Minimum version | Notes |
|---|---|---|
| macOS | 14 Sonoma | Required by Xcode 15 |
| Xcode | 15.0 | Available on the Mac App Store |
| iOS SDK | 17.0 | Bundled with Xcode 15 |
| Interactive Brokers TWS | 10.19 | Desktop app; download from ibkr.com |

---

## 2. Clone and open

```bash
git clone https://github.com/joezambito/AWC.git
cd AWC
open "Wealth Creation.xcodeproj"
```

---

## 3. Signing and provisioning

1. Select the **Wealth Creation** target in Xcode's project navigator.
2. Under **Signing & Capabilities**, choose your **Team**.
3. Change the **Bundle Identifier** if required (e.g. `com.yourname.AWC`).
4. Connect your device and select it as the run destination.
5. Press **⌘R** to build.

---

## 4. Create the awc.env configuration file

AWC reads sensitive connection parameters from a plain-text file on the
device.  The file must be placed in the app's **Documents** folder.

### Step-by-step (physical device)

1. Run the app once so Xcode provisions the Documents folder.
2. In Xcode: **Window → Devices and Simulators → (your device)**.
3. Select the AWC app container and click the download icon
   (**Download Container…**).
4. Navigate into the container to `AppData/Documents/`.
5. Create a plain-text file named `awc.env` with the content below.
6. Re-upload the container.

### Step-by-step (simulator)

```bash
# Find the simulator's Documents path
# Replace <SIMULATOR_ID> and <APP_BUNDLE_ID> with your values
DOCS_PATH=~/Library/Developer/CoreSimulator/Devices/<SIMULATOR_ID>/data/Containers/Data/Application/<APP_BUNDLE_ID>/Documents
cp .env.example "$DOCS_PATH/awc.env"
# Edit the file with your real values
open "$DOCS_PATH/awc.env"
```

### awc.env format

```
IBKR_CLIENT_ID=77
IBKR_HOST=192.168.1.21
IBKR_PORT=7497
MARKET_DATA_BASE_URL=https://api.example.com
```

---

## 5. Configure Interactive Brokers TWS

1. Open TWS on the same LAN as your device.
2. Navigate to **Edit → Global Configuration → API → Settings**.
3. Enable **Enable ActiveX and Socket Clients**.
4. Set **Socket port** to match `IBKR_PORT` in `awc.env` (default `7497`).
5. Add the IP address of your device to the **Trusted IP Addresses** list
   if TWS requests it.
6. Ensure **Allow connections from localhost only** is **disabled** if
   your device is on a different host than TWS.

---

## 6. Run the app

1. Build and run on your device (⌘R).
2. The startup sequence runs automatically:
   - Cache restore (instant; no UI freeze)
   - Universe scan → AI scan → Market ranking → Research feeds
   - Recurring timers start after the sequence completes
3. Open the **Dashboard** tab to see ranked opportunities.
4. Open the **Activity** tab to review AI Live candidates.

---

## 7. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| "IBKR API not ready" in event log | TWS not running or API disabled | Start TWS; enable API in Global Configuration |
| "awc.env not found" warning | Config file missing | Follow step 4 above |
| Empty Dashboard on launch | No cached data yet | Wait for first startup scan to complete |
| Connection refused | Wrong host/port in awc.env | Verify IBKR_HOST and IBKR_PORT match TWS settings |
