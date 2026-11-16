import SwiftUI
import WebKit

/// Immersive wrapper that loads the bundled Eaglet client from the app bundle.
/// Uses Bundle.main.url(forResource:"Eaglet", withExtension:"html") and loadFileURL(_:allowingReadAccessTo:).
struct EaglerWebView: UIViewRepresentable {
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

        loadBundledGame(in: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    private func loadBundledGame(in webView: WKWebView) {
        guard let fileURL = Bundle.main.url(forResource: "Eaglet", withExtension: "html") else {
            assertionFailure("Missing bundled resource: Eaglet.html")
            let message = "<html><body style='background:#000;color:#fff;font-family:-apple-system'>Missing bundled Eaglet.html</body></html>"
            webView.loadHTMLString(message, baseURL: nil)
            return
        }
        webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
    }
}
