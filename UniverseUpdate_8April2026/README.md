# Universe Update 8/4/2026

Four Swift files have been rewritten.  Replace each file in your Xcode project with the version of the same name from this folder.  Do not alter any other files.

## Files included

| File | What changed |
|------|-------------|
| WealthMarketUniverseStore+StartupCache.swift | Removed the hardcoded 127,000 – 128,631 record count band.  The cache is accepted as long as it has at least 25,000 records and valid region data.  The universe can now grow to any size the device can handle. |
| WealthMarketUniverseStore.swift | The app no longer re-downloads the universe every time it opens.  Once a valid cache exists the store uses it without triggering a background refresh.  A background load only updates the cache when the new record count is different from what is already saved. |
| WealthOpportunityDisplayState.swift | The AI Live 5-minute card expiry has been removed.  A ranked card now stays valid for 24 hours instead of 5 minutes.  Cards leave AI Live only when bought, rejected, or flagged by a hard safety check. |
| WealthEngineStore.swift | The downstream recovery stale interval has been extended from 5 minutes to 24 hours to match the new AI Live card persistence window.  The engine will not force a full recovery scan just because the last refresh was more than 5 minutes ago. |

## How to apply

1. Open your project in Xcode.
2. For each file above, right-click the existing file in the Project Navigator and choose "Show in Finder".
3. Replace the file on disk with the version from this folder.
4. Build and run.
