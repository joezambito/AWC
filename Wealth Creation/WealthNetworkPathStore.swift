import Foundation
import Combine
import Network

@MainActor
final class WealthNetworkPathStore: ObservableObject {
    static let shared = WealthNetworkPathStore()

    @Published private(set) var isSatisfied = false
    @Published private(set) var isWiFi = false
    @Published private(set) var isCellular = false
    @Published private(set) var isExpensive = false
    @Published private(set) var isConstrained = false
    @Published private(set) var transportLabel = "offline"

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.zulugames.awc.network-path", qos: .utility)

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.apply(path)
            }
        }
        monitor.start(queue: queue)
    }

    var isFallbackCellular: Bool {
        isCellular && !isWiFi
    }

    private func apply(_ path: NWPath) {
        isSatisfied = path.status == .satisfied
        isWiFi = path.usesInterfaceType(.wifi)
        isCellular = path.usesInterfaceType(.cellular)
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        transportLabel = Self.transportLabel(for: path)

        #if DEBUG
        print(
            "[NetworkPath] status=\(isSatisfied ? "satisfied" : "unsatisfied") " +
            "transport=\(transportLabel) " +
            "wifi=\(isWiFi) " +
            "cellular=\(isCellular) " +
            "expensive=\(isExpensive) " +
            "constrained=\(isConstrained)"
        )
        #endif
    }

    private static func transportLabel(for path: NWPath) -> String {
        if path.status != .satisfied { return "offline" }
        if path.usesInterfaceType(.wifi) { return "wifi" }
        if path.usesInterfaceType(.cellular) { return "cellular" }
        if path.usesInterfaceType(.wiredEthernet) { return "wired" }
        return "other"
    }
}
