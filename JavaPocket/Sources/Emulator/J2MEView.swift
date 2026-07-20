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
    private lazy var networkBridge = J2MENetworkBridge(webView: webView)
    private var readinessAttempts = 0

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
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.scrollView.contentInset = .zero
        view.scrollView.scrollIndicatorInsets = .zero
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
        evaluate("if (window.j2meAPI && window.j2meAPI.pause) window.j2meAPI.pause();")
    }

    func resume() {
        evaluate("if (window.j2meAPI && window.j2meAPI.resume) window.j2meAPI.resume();")
    }

    func setMuted(_ muted: Bool) {
        evaluate("if (window.j2meAPI && window.j2meAPI.setMute) window.j2meAPI.setMute(\(muted));")
    }

    func setSpeed(_ multiplier: Double) {
        let value = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), multiplier)
        evaluate("if (window.j2meAPI && window.j2meAPI.setSpeed) window.j2meAPI.setSpeed(\(value));")
    }

    func save(completion: ((Bool) -> Void)? = nil) {
        saveCompletion = completion
        evaluate("""
        (function() {
            if (!window.j2meAPI || !window.j2meAPI.getSaveData) {
            window.webkit.messageHandlers.j2me.postMessage({type:'getSaveDataResult', base64:null});
            return;
          }
          window.j2meAPI.getSaveData().then(function(value) {
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

        let screen = "\(game.screenWidth)x\(game.screenHeight)"
        let fontSize = Self.classicJ2MEFontSize(
            width: game.screenWidth,
            height: game.screenHeight
        )
        let script = """
        (async function() {
          try {
            const response = await fetch(\(Self.jsString(jarURL.absoluteString)));
            if (!response.ok) throw new Error('HTTP ' + response.status);
            const bytes = new Uint8Array(await response.arrayBuffer());
            if (!window.j2me || !window.j2me.openJar) throw new Error('J2meJS API unavailable');
            if (window.j2meAPI && window.j2meAPI.setScaleMode) {
              window.j2meAPI.setScaleMode('stretch');
            }
            // J2meJS otherwise enforces a 19px minimum font even on classic
            // 128/176/240px canvases. Chinese Nokia games usually wrap text
            // for the smaller device font, so that default clips the last
            // glyphs at the logical canvas edge.
            if (window.j2meAPI && window.j2meAPI.setConfig) {
              window.j2meAPI.setConfig('fontSize', \(fontSize));
            }
            if (\(saveBase64) && window.j2meAPI && window.j2meAPI.loadSaveData) {
              window.j2meAPI.loadSaveData(\(saveBase64));
            }
            window.j2me.openJar(bytes, \(Self.jsString(game.jarFileName)),
                                \(Self.jsString(screen)), \(game.isScreenRotationEnabled));
            setTimeout(function() {
              if (window.j2meAPI && window.j2meAPI.safeApply) window.j2meAPI.safeApply();
            }, 800);
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

    /// Medium system-font sizes used by classic Java ME phone resolutions.
    /// This is based on logical canvas width, not the iPhone/WebView size.
    private static func classicJ2MEFontSize(width: Int, height: Int) -> Int {
        switch min(width, height) {
        case ..<112:  return 10
        case ..<150:  return 11
        case ..<220:  return 13
        case ..<300:  return 16
        case ..<350:  return 18
        default:      return 20
        }
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
        case "evalNative":
            if let command = payload["command"] as? String,
               let data = payload["data"] as? [String: Any] {
                networkBridge.handle(command: command, data: data)
            }
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
        let readinessScript = """
        typeof window.j2me !== 'undefined' &&
        typeof CLASSES !== 'undefined' && !!CLASSES.java_lang_Object &&
        typeof JARStore !== 'undefined' && typeof MIDP !== 'undefined' && typeof jvm !== 'undefined'
        """
        webView.evaluateJavaScript(readinessScript) { [weak self] result, error in
            guard let self else { return }
            if result as? Bool == true {
                self.isRuntimeReady = true
                self.openGameIfPossible()
            } else {
                self.readinessAttempts += 1
                if self.readinessAttempts >= 40 {
                    self.onError?(error?.localizedDescription ?? "J2ME 引擎初始化超时，请重新进入游戏。")
                    return
                }
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
