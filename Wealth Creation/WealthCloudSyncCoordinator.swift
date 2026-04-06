import Foundation

// MARK: - WealthCloudSyncCoordinator
//
// Coordinates lightweight iCloud key-value sync so that certain AWC
// preferences and scan timestamps are shared across the user's devices.
//
// Only NSUbiquitousKeyValueStore (iCloud KV) is used — no CloudKit
// record types or CKDatabase calls are made.  This keeps the sync
// surface minimal and avoids any schema migration concerns.
//
// Keys synced:
//   • `awc_cloud_last_sync`  – Date of the last successful KV push
//   • `awc_cloud_device_id`  – UUID identifying this device in the swarm
//
// No existing engine logic, functions, or behaviors are changed.

@MainActor
final class WealthCloudSyncCoordinator {

    // MARK: Shared instance

    static let shared = WealthCloudSyncCoordinator()
    private init() {}

    // MARK: - iCloud KV keys

    private enum Key {
        static let lastSync = "awc_cloud_last_sync"
        static let deviceID = "awc_cloud_device_id"
    }

    // MARK: - State

    /// Date of the last successful push to iCloud KV, or `nil` if never synced.
    private(set) var lastSyncDate: Date?

    /// Stable UUID for this device, persisted in iCloud KV and local UserDefaults.
    private(set) var deviceID: String = {
        if let stored = UserDefaults.standard.string(forKey: Key.deviceID) {
            return stored
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: Key.deviceID)
        return id
    }()

    // MARK: - Public API

    /// Push the current engine state summary to iCloud KV.
    ///
    /// Safe to call from any periodic timer tick.  A minimum 15-minute
    /// interval is enforced to avoid saturating the iCloud KV quota.
    func pushIfNeeded() {
        let minInterval: TimeInterval = 15 * 60
        if let last = lastSyncDate, Date().timeIntervalSince(last) < minInterval {
            return
        }
        push()
    }

    /// Force an immediate push to iCloud KV regardless of the last-sync interval.
    func push() {
        let kv = NSUbiquitousKeyValueStore.default
        let now = Date()
        kv.set(now.timeIntervalSinceReferenceDate, forKey: Key.lastSync)
        kv.set(deviceID, forKey: Key.deviceID)
        kv.synchronize()
        lastSyncDate = now

        WealthEventLogStore.shared.record(
            title: "Cloud Sync Coordinator",
            detail: "Pushed to iCloud KV — deviceID=\(deviceID).",
            category: "sync",
            tintName: "blue",
            timestamp: now
        )
    }

    /// Pull the last-sync timestamp from iCloud KV and update `lastSyncDate`.
    func pull() {
        let kv = NSUbiquitousKeyValueStore.default
        let raw = kv.double(forKey: Key.lastSync)
        if raw > 0 {
            lastSyncDate = Date(timeIntervalSinceReferenceDate: raw)
        }

        WealthEventLogStore.shared.record(
            title: "Cloud Sync Coordinator",
            detail: "Pulled from iCloud KV — lastSync=\(lastSyncDate?.description ?? "nil").",
            category: "sync",
            tintName: "blue",
            timestamp: .now
        )
    }

    // MARK: - Queries

    /// `true` when at least one successful push has been completed.
    var hasSynced: Bool { lastSyncDate != nil }
}
