import SwiftUI
import WebKit

/// Immersive wrapper that loads a selected bundled client in a browser-chrome-free WKWebView.
struct EaglerWebView: UIViewRepresentable {
    let fileURL: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // Reduce browser-like behaviors where possible for a stable game surface.
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.bouncesZoom = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false

        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif

        loadSelectedClient(in: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    private func loadSelectedClient(in webView: WKWebView) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            assertionFailure("Missing bundled resource: \(fileURL.lastPathComponent)")
            let message = "<html><body style='background:#000;color:#fff;font-family:-apple-system'>Missing bundled client: \(fileURL.lastPathComponent)</body></html>"
            webView.loadHTMLString(message, baseURL: nil)
            return
        }
        webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
    }
}
