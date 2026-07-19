import UIKit
import WebKit

@MainActor
final class J2MEView: UIView {
    var onReady: (() -> Void)?
    var onError: ((String) -> Void)?
    var onExit: (() -> Void)?

    private let game: GameRecord
    private let storage: GameStorage
    private let shouldLoadSave: Bool
    private let localServer = J2MELocalServer()
    private var pressedButtons: Set<J2MEButton> = []
    private var isRuntimeReady = false
    private var didOpenGame = false
    private var saveCompletion: ((Bool) -> Void)?

    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = .default()

        let controller = WKUserContentController()
        controller.add(WeakJ2MEScriptMessageHandler(target: self), name: "j2me")
        configuration.userContentController = controller

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self
        view.uiDelegate = self
        view.scrollView.isScrollEnabled = false
        view.scrollView.bounces = false
        view.isOpaque = true
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    init(game: GameRecord, storage: GameStorage, shouldLoadSave: Bool) {
        self.game = game
        self.storage = storage
        self.shouldLoadSave = shouldLoadSave
        super.init(frame: .zero)
        backgroundColor = .black
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        startRuntime()
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        localServer.stop()
    }

    func press(_ button: J2MEButton, pressed: Bool) {
        if pressed {
            guard pressedButtons.insert(button).inserted else { return }
        } else {
            pressedButtons.remove(button)
        }
        let action = pressed ? "keyDown" : "keyUp"
        evaluate("if (window.Input) window.Input.\(action)(\(Self.jsString(button.keyCode)));" )
    }

    func pause() {
        evaluate("if (window.freej2meAPI && window.freej2meAPI.pause) window.freej2meAPI.pause();")
    }

    func resume() {
        evaluate("if (window.freej2meAPI && window.freej2meAPI.resume) window.freej2meAPI.resume();")
    }

    func setMuted(_ muted: Bool) {
        evaluate("if (window.freej2meAPI && window.freej2meAPI.setMute) window.freej2meAPI.setMute(\(muted));")
    }

    func save(completion: ((Bool) -> Void)? = nil) {
        saveCompletion = completion
        evaluate("""
        (function() {
          if (!window.freej2meAPI || !window.freej2meAPI.getSaveData) {
            window.webkit.messageHandlers.j2me.postMessage({type:'getSaveDataResult', base64:null});
            return;
          }
          window.freej2meAPI.getSaveData().then(function(value) {
            window.webkit.messageHandlers.j2me.postMessage({type:'getSaveDataResult', base64:value});
          }).catch(function(error) {
            window.webkit.messageHandlers.j2me.postMessage({type:'getSaveDataResult', base64:null, error:String(error)});
          });
        })();
        """)
    }

    private func startRuntime() {
        do {
            try localServer.start()
            guard let url = localServer.indexURL else {
                onError?("无法创建 J2ME 运行地址。")
                return
            }
            webView.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy))
        } catch {
            onError?("J2ME 运行时启动失败：\(error.localizedDescription)")
        }
    }

    private func openGameIfPossible() {
        guard isRuntimeReady, !didOpenGame else { return }
        let jar = storage.jarURL(for: game)
        guard FileManager.default.fileExists(atPath: jar.path),
              let jarURL = localServer.register(jar)
        else {
            onError?(GameStorageError.gameNotFound.localizedDescription)
            return
        }
        didOpenGame = true

        let saveBase64: String
        if shouldLoadSave,
           let data = try? Data(contentsOf: storage.rmsURL(for: game.id)) {
            saveBase64 = Self.jsString(data.base64EncodedString())
        } else {
            saveBase64 = "null"
        }

        let locale = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
        let screen = "\(game.screenWidth)x\(game.screenHeight)"
        let script = """
        (async function() {
          try {
            const response = await fetch(\(Self.jsString(jarURL.absoluteString)));
            if (!response.ok) throw new Error('HTTP ' + response.status);
            const bytes = new Uint8Array(await response.arrayBuffer());
            if (!window.freej2meAPI || !window.freej2meAPI.openJar) throw new Error('FreeJ2ME API unavailable');
            await window.freej2meAPI.openJar(
              bytes,
              \(Self.jsString(game.jarFileName)),
              \(saveBase64),
              \(Self.jsString(locale)),
              \(Self.jsString(screen)),
              false
            );
            window.webkit.messageHandlers.j2me.postMessage({type:'openJarCompletion', success:true});
          } catch (error) {
            window.webkit.messageHandlers.j2me.postMessage({type:'openJarCompletion', success:false, error:String(error)});
          }
        })();
        """
        evaluate(script)
    }

    private func evaluate(_ script: String) {
        webView.evaluateJavaScript(script) { [weak self] _, error in
            if let error { self?.onError?(error.localizedDescription) }
        }
    }

    private static func jsString(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let array = String(data: data, encoding: .utf8)
        else { return "\"\"" }
        return String(array.dropFirst().dropLast())
    }

    fileprivate func handleMessage(_ body: Any) {
        guard let payload = body as? [String: Any],
              let type = payload["type"] as? String
        else { return }

        switch type {
        case "ready":
            isRuntimeReady = true
            openGameIfPossible()
        case "openJarCompletion":
            if payload["success"] as? Bool == true {
                onReady?()
            } else {
                onError?(payload["error"] as? String ?? "游戏启动失败。")
            }
        case "saveDataWritten":
            persistBase64(payload["data"] as? String)
        case "getSaveDataResult":
            let success = persistBase64(payload["base64"] as? String)
            saveCompletion?(success)
            saveCompletion = nil
        case "exit":
            save { [weak self] _ in self?.onExit?() }
        default:
            break
        }
    }

    @discardableResult
    private func persistBase64(_ value: String?) -> Bool {
        guard let value, let data = Data(base64Encoded: value) else { return false }
        do {
            try storage.writeRMS(data, for: game.id)
            return true
        } catch {
            onError?("存档写入失败：\(error.localizedDescription)")
            return false
        }
    }
}

extension J2MEView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pollRuntimeReady()
    }

    private func pollRuntimeReady() {
        webView.evaluateJavaScript("window.freej2meReady === true") { [weak self] result, _ in
            guard let self else { return }
            if result as? Bool == true {
                self.isRuntimeReady = true
                self.openGameIfPossible()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
                    self?.pollRuntimeReady()
                }
            }
        }
    }
}

extension J2MEView: WKUIDelegate {}

private final class WeakJ2MEScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: J2MEView?
    init(target: J2MEView) { self.target = target }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        Task { @MainActor [weak self] in self?.target?.handleMessage(message.body) }
    }
}
