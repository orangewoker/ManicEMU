import Foundation
import GCDWebServer

final class J2MELocalServer {
    private let server = GCDWebServer()
    private var files: [String: URL] = [:]
    private(set) var port: UInt = 0

    func start() throws {
        guard !server.isRunning else { return }
        guard let resources = Bundle.main.resourceURL?.appendingPathComponent("j2mejs"),
              FileManager.default.fileExists(atPath: resources.path)
        else {
            throw GameStorageError.gameNotFound
        }

        server.addGETHandler(
            forBasePath: "/",
            directoryPath: resources.path,
            indexFilename: nil,
            cacheAge: 3600,
            allowRangeRequests: true
        )

        let wasmHandler: GCDWebServerProcessBlock = { request in
            let path = resources.appendingPathComponent(request.path)
            guard FileManager.default.fileExists(atPath: path.path) else {
                return GCDWebServerResponse(statusCode: 404)
            }
            let response = GCDWebServerFileResponse(file: path.path)
            response?.contentType = "application/wasm"
            return response
        }
        server.addHandler(
            forMethod: "GET",
            pathRegex: "/.*\\.wasm",
            request: GCDWebServerRequest.self,
            processBlock: wasmHandler
        )

        let fileHandler: GCDWebServerProcessBlock = { [weak self] request in
            let identifier = URL(fileURLWithPath: request.path).lastPathComponent
            guard let self,
                  let url = self.files[identifier],
                  FileManager.default.fileExists(atPath: url.path)
            else { return GCDWebServerResponse(statusCode: 404) }
            let response = GCDWebServerFileResponse(file: url.path)
            response?.cacheControlMaxAge = 0
            response?.setValue("no-cache, no-store, must-revalidate", forAdditionalHeader: "Cache-Control")
            response?.contentType = "application/java-archive"
            return response
        }
        server.addHandler(
            forMethod: "GET",
            pathRegex: "/file/.*",
            request: GCDWebServerRequest.self,
            processBlock: fileHandler
        )

        try server.start(options: [
            GCDWebServerOption_Port: 0,
            GCDWebServerOption_BindToLocalhost: true,
            GCDWebServerOption_AutomaticallySuspendInBackground: false
        ])
        port = server.port
    }

    func register(_ url: URL) -> URL? {
        let identifier = UUID().uuidString
        files[identifier] = url
        return URL(string: "http://127.0.0.1:\(port)/file/\(identifier)")
    }

    var indexURL: URL? {
        URL(string: "http://127.0.0.1:\(port)/index.html")
    }

    func stop() {
        server.stop()
        files.removeAll()
    }
}
