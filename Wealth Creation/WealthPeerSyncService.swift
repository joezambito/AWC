import Foundation
import Network
import OSLog

// MARK: - WealthPeerInfo

struct WealthPeerInfo: Equatable {
    let name: String
}

// MARK: - WealthPeerSyncService

@MainActor
final class WealthPeerSyncService {

    // MARK: - Shared instance

    static let shared = WealthPeerSyncService()

    // MARK: - Constants

    private static let bonjourType = "_awc._tcp"

    // MARK: - Network queue
    //
    // NWListener and NWBrowser callbacks are delivered on this private serial
    // queue. Every callback hops to @MainActor via Task { @MainActor in ... }
    // so all state mutations remain on the main actor.
    private static let peerSyncQueue = DispatchQueue(
        label: "com.awc.wealth.peer-sync",
        qos: .utility
    )

    // MARK: - State

    @Published private(set) var discoveredPeers: [WealthPeerInfo] = []

    // MARK: - Private properties

    private var listener: NWListener?
    private var browser: NWBrowser?
    private let log = Logger(subsystem: "AWC", category: "PeerSync")

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    func start() {
        stop()
        advertise()
        browse()
    }

    func stop() {
        listener?.cancel()
        listener = nil
        browser?.cancel()
        browser = nil
        discoveredPeers.removeAll()

        log.info("PeerSyncService: stopped.")
    }

    // MARK: - Advertising

    private func advertise() {
        guard let l = try? NWListener(using: .tcp) else {
            log.error("PeerSyncService: failed to create NWListener.")
            return
        }
        l.service = NWListener.Service(type: Self.bonjourType)
        l.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.handleListenerState(state)
            }
        }
        l.newConnectionHandler = { connection in
            connection.cancel()
        }
        l.start(queue: Self.peerSyncQueue)
        listener = l
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            log.info("PeerSyncService: advertising on Bonjour.")
        case .failed(let error):
            log.error("PeerSyncService: listener failed – \(error.localizedDescription).")
        default:
            break
        }
    }

    // MARK: - Discovery

    private func browse() {
        let descriptor = NWBrowser.Descriptor.bonjour(type: Self.bonjourType, domain: nil)
        let b = NWBrowser(for: descriptor, using: .tcp)
        b.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.handleBrowserState(state)
            }
        }
        b.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                self?.handleBrowseResults(results)
            }
        }
        b.start(queue: Self.peerSyncQueue)
        browser = b
    }

    private func handleBrowserState(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            log.info("PeerSyncService: browsing for peers.")
        case .failed(let error):
            log.error("PeerSyncService: browser failed – \(error.localizedDescription).")
        default:
            break
        }
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        discoveredPeers = results.compactMap { result in
            guard case .service(let name, _, _, _) = result.endpoint else { return nil }
            return WealthPeerInfo(name: name)
        }
        log.info("PeerSyncService: \(self.discoveredPeers.count) peer(s) visible.")
    }
}
