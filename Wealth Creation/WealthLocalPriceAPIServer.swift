import Foundation
import Network

final class WealthLocalPriceAPIServer {
    static let shared = WealthLocalPriceAPIServer()

    private let queue = DispatchQueue(label: "com.zulugames.awc.livepriceapi")
    private let port: UInt16 = 8787
    private var listener: NWListener?

    private init() {}

    func startIfNeeded() {
        guard listener == nil else { return }
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }

        do {
            let listener = try NWListener(using: .tcp, on: nwPort)
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.start(queue: queue)
            self.listener = listener
            Task { @MainActor in
                WealthLiveMarketDataStore.shared.setAPIPort(Int(self.port))
            }
        } catch {
            Task { @MainActor in
                WealthLiveMarketDataStore.shared.noteError(code: nil, message: "API server failed: \(error.localizedDescription)", requestID: nil, key: nil)
            }
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8_192) { data, _, _, _ in
            let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let path = Self.path(from: request)
            Task { @MainActor in
                let body: Data
                let statusLine: String

                if path.hasPrefix("/api/prices") {
                    body = WealthLiveMarketDataStore.shared.apiResponseData(path: path)
                    statusLine = "HTTP/1.1 200 OK\r\n"
                } else {
                    body = Data("{\"error\":\"Not Found\"}".utf8)
                    statusLine = "HTTP/1.1 404 Not Found\r\n"
                }

                let headers = [
                    statusLine,
                    "Content-Type: application/json\r\n",
                    "Content-Length: \(body.count)\r\n",
                    "Connection: close\r\n\r\n"
                ].joined()

                connection.send(content: Data(headers.utf8) + body, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }

    private static func path(from request: String) -> String {
        guard let firstLine = request.split(separator: "\n").first else { return "/" }
        let pieces = firstLine.split(separator: " ")
        guard pieces.count >= 2 else { return "/" }
        return String(pieces[1])
    }
}
