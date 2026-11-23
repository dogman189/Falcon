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

    private var webView: WKWebView?
    private var isLoaded = false
    private var currentRequestID: String?
    private var pendingPack: (() -> Void)?

    func loadIfNeeded() {
        if webView != nil {
            return
        }

        let configuration = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(self, name: "falconRetroPacker")
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif
        self.webView = webView

        guard let url = packerResourceURL() else {
            onError?("Missing retro packer resource (pack_game_en.html).")
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    func pack(romData: Data, romName: String, system: String, title: String, color: String = "#FF4444") {
        loadIfNeeded()

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

        let perform: () -> Void = { [weak self] in
            guard let self else { return }
            guard let webView = self.webView else { return }
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
                            self.currentRequestID = nil
                            self.onError?(error.localizedDescription)
                        }
                    }
                }
            } catch {
                if self.currentRequestID == id {
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
        currentRequestID = nil
        pendingPack = nil
        isLoaded = false

        guard let webView else { return }
        webView.stopLoading()
        guard let url = packerResourceURL() else { return }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "falconRetroPacker" else { return }
        guard let event = RetroPackerBridgeParser.parse(message.body) else { return }

        switch event {
        case .progress(let id, let percent, let messageText):
            guard id == currentRequestID else { return }
            onProgress?(percent, messageText)

        case .complete(let id, let fileName, let htmlBase64):
            guard id == currentRequestID else { return }
            currentRequestID = nil
            guard let htmlData = Data(base64Encoded: htmlBase64) else {
                onError?("Unable to decode generated HTML.")
                return
            }
            onComplete?(fileName, htmlData)

        case .failed(let id, let messageText):
            guard id == currentRequestID else { return }
            currentRequestID = nil
            onError?(messageText)
        }
    }

    // MARK: - Resource loading

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
        isLoaded = true
        if let pending = pendingPack {
            pendingPack = nil
            pending()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if currentRequestID != nil {
            currentRequestID = nil
            onError?(error.localizedDescription)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if currentRequestID != nil {
            currentRequestID = nil
            onError?(error.localizedDescription)
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        isLoaded = false
        if currentRequestID != nil {
            currentRequestID = nil
            onError?("The retro packer stopped unexpectedly.")
        }
    }
}