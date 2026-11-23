import Foundation
import WebKit

/// Drives the vendored universal retro packer (`pack_game_en.html`) inside a
/// hidden `WKWebView` and bridges its progress/completion/error events back to
/// native callers.
@MainActor
final class RetroPackerEngine: NSObject, WKScriptMessageHandler {
    var onProgress: ((Double, String) -> Void)?
    var onComplete: ((String, Data) -> Void)?
    var onError: ((String) -> Void)?

    /// Exposed so Task 7 can host this web view in a view hierarchy (off-screen
    /// if needed). The instance may be replaced after a reset/reload.
    var webView: WKWebView? { _webView }

    private var _webView: WKWebView?
    private var isLoaded = false
    private var currentRequestID: String?
    private var pendingPack: (() -> Void)?
    private var timeoutTask: Task<Void, Never>?

    func loadIfNeeded() {
        if _webView != nil {
            return
        }

        guard let url = packerResourceURL() else {
            if currentRequestID != nil {
                timeoutTask?.cancel()
                timeoutTask = nil
                let id = currentRequestID
                currentRequestID = nil
                onError?("Missing retro packer resource (pack_game_en.html).")
                _ = id
            }
            return
        }

        let configuration = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(RetroPackerMessageProxy(owner: self), name: "falconRetroPacker")
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif
        _webView = webView

        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    func pack(romData: Data, romName: String, system: String, title: String, color: String = "#FF4444") {
        let id = UUID().uuidString
        currentRequestID = id

        let request = RetroPackRequest(
            id: id,
            romBase64: romData.base64EncodedString(),
            romName: romName,
            system: system,
            title: title,
            color: color
        )

        loadIfNeeded()
        guard _webView != nil else {
            // loadIfNeeded already reported the failure (if any).
            if currentRequestID == id {
                currentRequestID = nil
            }
            timeoutTask?.cancel()
            timeoutTask = nil
            return
        }

        startTimeout(for: id)

        let perform: () -> Void = { [weak self] in
            guard let self else { return }
            guard let webView = self._webView else { return }
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(request)
                guard let jsonString = String(data: data, encoding: .utf8) else {
                    throw NSError(domain: "RetroPackerEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode packing request."])
                }
                let script = "window.FalconRetroPacker.pack(\(jsonString));"
                webView.evaluateJavaScript(script) { [weak self] _, error in
                    Task { @MainActor in
                        guard let self else { return }
                        if let error, self.currentRequestID == id {
                            self.timeoutTask?.cancel()
                            self.timeoutTask = nil
                            self.currentRequestID = nil
                            self.onError?(error.localizedDescription)
                        }
                    }
                }
            } catch {
                if self.currentRequestID == id {
                    self.timeoutTask?.cancel()
                    self.timeoutTask = nil
                    self.currentRequestID = nil
                    self.onError?(error.localizedDescription)
                }
            }
        }

        if isLoaded {
            perform()
        } else {
            pendingPack = perform
        }
    }

    func cancel() {
        timeoutTask?.cancel()
        timeoutTask = nil
        currentRequestID = nil
        pendingPack = nil
        resetWebView()
        loadIfNeeded()
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Forwarded by the proxy; kept to satisfy the protocol if registered directly.
        handleScriptMessage(message)
    }

    func handleScriptMessage(_ message: WKScriptMessage) {
        guard message.name == "falconRetroPacker" else { return }
        guard let event = RetroPackerBridgeParser.parse(message.body) else { return }

        switch event {
        case .progress(let id, let percent, let messageText):
            guard id == currentRequestID else { return }
            onProgress?(percent, messageText)

        case .complete(let id, let fileName, let htmlBase64):
            guard id == currentRequestID else { return }
            timeoutTask?.cancel()
            timeoutTask = nil
            currentRequestID = nil
            guard let htmlData = Data(base64Encoded: htmlBase64) else {
                onError?("Unable to decode generated HTML.")
                return
            }
            onComplete?(fileName, htmlData)

        case .failed(let id, let messageText):
            guard id == currentRequestID else { return }
            timeoutTask?.cancel()
            timeoutTask = nil
            currentRequestID = nil
            onError?(messageText)
        }
    }

    // MARK: - Internals

    private func startTimeout(for id: String) {
        timeoutTask?.cancel()
        timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000_000)
            guard let self else { return }
            guard self.currentRequestID == id else { return }
            self.currentRequestID = nil
            self.timeoutTask = nil
            self.resetWebView()
            self.onError?("Packing timed out.")
        }
    }

    private func resetWebView(reportingError message: String? = nil) {
        timeoutTask?.cancel()
        timeoutTask = nil

        if let webView = _webView {
            webView.stopLoading()
            webView.navigationDelegate = nil
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "falconRetroPacker")
            _webView = nil
        }
        isLoaded = false
        pendingPack = nil

        if let message, currentRequestID != nil {
            currentRequestID = nil
            onError?(message)
        }
    }

    private func packerResourceURL() -> URL? {
        if let url = Bundle.main.url(forResource: "pack_game_en", withExtension: "html", subdirectory: "RetroPacker"),
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        if let url = Bundle.main.url(forResource: "pack_game_en", withExtension: "html"),
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        if let base = Bundle.main.resourceURL {
            let subdirCandidate = base.appendingPathComponent("RetroPacker/pack_game_en.html")
            if FileManager.default.fileExists(atPath: subdirCandidate.path) {
                return subdirCandidate
            }
            let rootCandidate = base.appendingPathComponent("pack_game_en.html")
            if FileManager.default.fileExists(atPath: rootCandidate.path) {
                return rootCandidate
            }
        }
        return nil
    }
}

extension RetroPackerEngine: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === _webView else { return }
        isLoaded = true
        if let pending = pendingPack {
            pendingPack = nil
            pending()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard webView === _webView else { return }
        resetWebView(reportingError: error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard webView === _webView else { return }
        resetWebView(reportingError: error.localizedDescription)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard webView === _webView else { return }
        resetWebView(reportingError: "The retro packer stopped unexpectedly.")
    }
}

/// Lightweight proxy so `WKUserContentController` does not retain the engine.
private final class RetroPackerMessageProxy: NSObject, WKScriptMessageHandler {
    weak var owner: RetroPackerEngine?

    init(owner: RetroPackerEngine) {
        self.owner = owner
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        Task { @MainActor [weak self] in
            self?.owner?.handleScriptMessage(message)
        }
    }
}