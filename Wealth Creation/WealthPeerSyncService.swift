import Foundation
import Network
import OSLog

// MARK: - WealthPeerInfo

/// Represents a discovered AWC peer device on the local network.
struct WealthPeerInfo: Equatable {
    /// The Bonjour instance name of the remote peer (typically the device name).
    let name: String
}

// MARK: - WealthPeerSyncService

// NEW FILE
//
// Enables AWC instances running on different Apple devices (Mac, iPhone, iPad)
// on the same local network to advertise themselves and discover each other
// as peers.
//
// Advertising: each instance registers a Bonjour service of type `_awc._tcp`
//   via `NWListener` so that other devices on the same Wi-Fi/LAN can see it.
//
// Discovery: each instance runs an `NWBrowser` that continuously scans for
//   other `_awc._tcp` services and populates `discoveredPeers`.
//
// No existing engine logic, functions, or behaviors are changed.

@MainActor
final class WealthPeerSyncService {

    // MARK: - Shared instance

    static let shared = WealthPeerSyncService()

    // MARK: - Constants

    private static let bonjourType = "_awc._tcp"

    // MARK: - State

    /// AWC peers currently visible on the local network.
    ///
    /// Updated whenever the browser's result set changes.  Each entry
    /// corresponds to one remote device running AWC on the same LAN.
    private(set) var discoveredPeers: [WealthPeerInfo] = []

    // MARK: - Private properties

    private var listener: NWListener?
    private var browser: NWBrowser?
    private let log = Logger(subsystem: "AWC", category: "PeerSync")

    /// Dedicated dispatch queue for NWListener and NWBrowser callbacks.
    ///
    /// Using `.main` for Network framework objects delivers every TCP-level
    /// event on the main thread, flooding the run loop with Bonjour packets
    /// whenever multiple AWC peers are visible.  A private utility queue
    /// keeps all network I/O off the main thread; any state mutation that
    /// touches @Published properties is hopped back to @MainActor inside
    /// the existing `Task { @MainActor in … }` handlers.
    private static let peerSyncQueue = DispatchQueue(
        label: "com.awg.wealth.peer-sync",
        qos: .utility
    )

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Start advertising this device and browsing for other AWC peers.
    ///
    /// Safe to call multiple times; any running session is stopped first
    /// so the listener and browser are always in a consistent state.
    func start() {
        stop()
        advertise()
        browse()
    }

    /// Stop advertising and browsing.  Clears `discoveredPeers`.
    func stop() {
        listener?.cancel()
        listener = nil
        browser?.cancel()
        browser = nil
        discoveredPeers.removeAll()
    }

    // MARK: - Advertisement (NWListener)

    private func advertise() {
        guard let l = try? NWListener(using: .tcp) else {
            log.error("PeerSync: NWListener init failed")
            return
        }
        l.service = NWListener.Service(type: Self.bonjourType)
        l.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in self?.listenerDidChangeState(state) }
        }
        l.newConnectionHandler = { _ in
            // Peer connections are for discovery only; no data transfer.
        }
        l.start(queue: Self.peerSyncQueue)
        listener = l
    }

    private func listenerDidChangeState(_ state: NWListener.State) {
        switch state {
        case .ready:
            log.info("PeerSync: advertising \(Self.bonjourType)")
        case .failed(let error):
            log.error("PeerSync: listener failed – \(error.localizedDescription)")
            listener = nil
        case .cancelled:
            log.info("PeerSync: listener cancelled")
        default:
            break
        }
    }

    // MARK: - Discovery (NWBrowser)

    private func browse() {
        let descriptor = NWBrowser.Descriptor.bonjour(type: Self.bonjourType, domain: nil)
        let b = NWBrowser(for: descriptor, using: .tcp)
        b.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in self?.browserDidChangeState(state) }
        }
        b.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                guard let self else { return }
                self.discoveredPeers = results.compactMap { result in
                    guard case .service(let name, _, _, _) = result.endpoint else { return nil }
                    return WealthPeerInfo(name: name)
                }
                self.log.info("PeerSync: \(self.discoveredPeers.count) peer(s) visible")
            }
        }
        b.start(queue: Self.peerSyncQueue)
        browser = b
    }

    private func browserDidChangeState(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            log.info("PeerSync: browsing for \(Self.bonjourType)")
        case .failed(let error):
            log.error("PeerSync: browser failed – \(error.localizedDescription)")
            browser = nil
        case .cancelled:
            log.info("PeerSync: browser cancelled")
        default:
            break
        }
    }
}
