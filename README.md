# AWC – Advanced Wealth Creation

AWC is a Mac Catalyst (iOS/macOS) trading-intelligence application built
with SwiftUI.  It connects to Interactive Brokers Trader Workstation (TWS)
over a local TCP connection, scans a universe of market opportunities, scores
them with an AI brain, and surfaces the highest-conviction candidates to an
Activity queue for review.

---

## Table of Contents

1. [Setup](#setup)
2. [Configuration](#configuration)
3. [Usage](#usage)
4. [Architecture](#architecture)
5. [Running Tests](#running-tests)
6. [Security](#security)

---

## Setup

### Requirements

| Requirement | Version |
|---|---|
| Xcode | 15.0 or later |
| iOS / Mac Catalyst | 17.0 or later |
| Swift | 5.9 or later |
| Interactive Brokers TWS | 10.19 or later (optional) |

### Build steps

```bash
# Clone the repository
git clone https://github.com/joezambito/AWC.git
cd AWC

# Open the Xcode project
open "Wealth Creation.xcodeproj"
```

Select the **Wealth Creation** scheme and the target device, then press
**⌘R** to build and run.

See [SETUP.md](SETUP.md) for detailed device provisioning, signing, and
TWS network configuration steps.

---

## Configuration

All sensitive configuration lives in a plain-text file on the device:

```
<Documents>/awc.env
```

Copy the template and fill in your values:

```bash
cp .env.example /path/to/awc.env   # then edit with real values
```

**Never commit `awc.env` to source control** — it is listed in `.gitignore`.

| Key | Description | Default |
|---|---|---|
| `IBKR_CLIENT_ID` | TWS client ID | `77` |
| `IBKR_HOST` | TWS LAN host address | *(empty — must be set)* |
| `IBKR_PORT` | TWS API port | `7497` |
| `MARKET_DATA_BASE_URL` | Market data REST API base URL | *(empty)* |

The app falls back to built-in defaults and logs a warning when `awc.env`
is absent.

---

## Usage

1. Start Interactive Brokers TWS on your desktop.
2. In TWS → **Global Configuration → API → Settings**: enable **Active X and
   Socket Clients** and set the port to match `IBKR_PORT`.
3. Launch the AWC app.  The engine bootstraps automatically:
   - Restores the last persisted snapshot (instant UI population).
   - Runs a staggered startup scan (universe → AI → market → research).
   - Schedules recurring refresh timers (9 / 10 / 19 / 20 / 29 / 30 min).
4. The **Dashboard** shows ranked opportunities and portfolio P&L.
5. The **Activity** tab shows the highest-conviction AI Live candidates
   ready for review.

---

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for a full component diagram.
Key components at a glance:

| Component | Responsibility |
|---|---|
| `WealthEngineStore` | Observable state container; all `@Published` properties |
| `WealthEngineStartupController` | Staggered startup scan sequence |
| `WealthEngineStore+Timers` | Six recurring refresh timers |
| `WealthEngineStore+Cache` / `BackgroundCache` | Atomic state persistence via `PersistenceManager` |
| `PersistenceManager` | Single-bundle atomic write (Issue 6 fix) |
| `MarketDataFetcher` | REST quote fetching; strong-capture async safety (Issue 7 fix) |
| `AWCSecretConfig` | `.env` loader; removes hardcoded credentials (Issue 8 fix) |
| `WealthIBKRBridge` | TCP connection to TWS; handshake, market data, portfolio sync |
| `WealthBrainStore` | AI scoring engine |
| `WealthAILiveCoordinator` | Promotes top-ranked cards to Activity |
| `WealthDownstreamCacheSanity` | File-backed AI Live / Market / Activity caches |

---

## Running Tests

```bash
# From the repository root
swift test
```

Tests are in `Tests/AWCTests/AWCTests.swift` and cover:

- **Timer scheduling** — correct timer count, invalidation, re-scheduling
- **Async object lifetime** — strong-capture pattern prevents mid-flight
  deallocation
- **Persistence atomicity** — atomic write / read / clear using a temp directory
- **Secret-config parsing** — `.env` parser handles comments, blanks, `=` in values
- **Error descriptions** — every `FetchError` case has a human-readable description

---

## Security

- `awc.env` is **never committed** (see `.gitignore`).
- No credentials, API keys, or secrets appear in source files.
- `AWCSecretConfig` is the sole point of configuration ingestion.
- All file writes use `Data.write(to:options:.atomic)` to prevent
  partial-write corruption.
