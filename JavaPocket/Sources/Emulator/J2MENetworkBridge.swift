import Foundation
import Network
import WebKit

@MainActor
final class J2MENetworkBridge {
    private weak var webView: WKWebView?
    private var sockets: [String: NWConnection] = [:]

    init(webView: WKWebView) {
        self.webView = webView
    }

    func handle(command: String, data: [String: Any]) {
        switch command {
        case "request": request(data)
        case "connectSocket": connect(data)
        case "invokeSocket": invoke(data)
        default: break
        }
    }

    private func request(_ data: [String: Any]) {
        guard let rawURL = data["url"] as? String, let url = URL(string: rawURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = data["method"] as? String ?? "GET"
        request.allHTTPHeaderFields = data["headers"] as? [String: String]
        if let body = data["data"] as? String { request.httpBody = Data(base64Encoded: body) }

        URLSession.shared.dataTask(with: request) { [weak self] body, response, error in
            var result: [String: Any] = [:]
            if let error { result["error"] = error.localizedDescription }
            if let response = response as? HTTPURLResponse {
                result["statusCode"] = response.statusCode
                result["headers"] = response.allHeaderFields.reduce(into: [String: String]()) {
                    $0[String(describing: $1.key)] = String(describing: $1.value)
                }
            }
            result["data"] = body?.base64EncodedString() ?? ""
            Task { @MainActor in self?.inject("window.__j2meNetworkCallbacks.request", payload: result) }
        }.resume()
    }

    private func connect(_ data: [String: Any]) {
        guard let id = data["id"] as? String,
              let host = data["host"] as? String,
              let portValue = data["port"] as? Int,
              let port = NWEndpoint.Port(rawValue: UInt16(portValue))
        else { return }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
        sockets[id] = connection
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.injectSocket(id: id, event: "connect")
                    self?.receive(id: id)
                case .failed(let error):
                    self?.injectSocket(id: id, event: "error", data: error.localizedDescription)
                    self?.sockets[id] = nil
                default: break
                }
            }
        }
        connection.start(queue: .global(qos: .userInitiated))
    }

    private func invoke(_ data: [String: Any]) {
        guard let id = data["id"] as? String, let method = data["method"] as? String else { return }
        if method == "destroy" {
            sockets.removeValue(forKey: id)?.cancel()
        } else if method == "write",
                  let base64 = data["data"] as? String,
                  let payload = Data(base64Encoded: base64) {
            sockets[id]?.send(content: payload, completion: .contentProcessed { _ in })
        }
    }

    private func receive(id: String) {
        sockets[id]?.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, complete, error in
            Task { @MainActor in
                if let data, !data.isEmpty {
                    self?.injectSocket(id: id, event: "data", data: data.base64EncodedString())
                }
                if complete || error != nil {
                    self?.injectSocket(id: id, event: "close")
                    self?.sockets[id] = nil
                } else {
                    self?.receive(id: id)
                }
            }
        }
    }

    private func injectSocket(id: String, event: String, data: String? = nil) {
        inject("window.__j2meNetworkCallbacks.socket", payload: [
            "id": id,
            "event": event,
            "data": data.map { $0 as Any } ?? NSNull()
        ])
    }

    private func inject(_ callback: String, payload: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8)
        else { return }
        webView?.evaluateJavaScript("if (\(callback)) \(callback)(\(json));")
    }
}
