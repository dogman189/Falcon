import SwiftUI
import WebKit

final class WebViewSnapshotter {
    fileprivate weak var webView: WKWebView?

    func takeSnapshot(completion: @escaping (UIImage?) -> Void) {
        guard let webView else {
            completion(nil)
            return
        }
        webView.takeSnapshot(with: nil) { image, _ in
            completion(image)
        }
    }
}

/// Immersive wrapper that loads a selected bundled client in a browser-chrome-free WKWebView.
struct EaglerWebView: UIViewRepresentable {
    let fileURL: URL
    var snapshotter: WebViewSnapshotter?
    var onFailure: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFailure: onFailure)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // Reduce browser-like behaviors where possible for a stable game surface.
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
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

        snapshotter?.webView = webView
        loadSelectedClient(in: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        snapshotter?.webView = uiView
    }

    private func loadSelectedClient(in webView: WKWebView) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            assertionFailure("Missing bundled resource: \(fileURL.lastPathComponent)")
            let message = "<html><body style='background:#000;color:#fff;font-family:-apple-system'>Missing bundled client: \(fileURL.lastPathComponent)</body></html>"
            webView.loadHTMLString(message, baseURL: nil)
            return
        }
        #if DEBUG
        NSLog("[Falcon] Loading %@", fileURL.absoluteString)
        #endif
        webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onFailure: (String) -> Void
        private var reportedFailure = false

        init(onFailure: @escaping (String) -> Void) {
            self.onFailure = onFailure
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            webView.stopLoading()
            report("""
            This client ran out of memory and iOS stopped it.

            Try the other bundled client, or reopen this one and use lower-memory options if available.
            """)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            reportLoadFailure(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            reportLoadFailure(error)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            #if DEBUG
            webView.evaluateJavaScript("location.href + ' | search=' + location.search + ' | hash=' + location.hash") { value, error in
                if let value {
                    NSLog("[Falcon] Loaded %@", String(describing: value))
                } else if let error {
                    NSLog("[Falcon] Could not read loaded URL: %@", String(describing: error))
                }
            }
            #endif
        }

        private func reportLoadFailure(_ error: Error) {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled {
                return
            }
            report("The client could not be loaded. \(error.localizedDescription)")
        }

        private func report(_ message: String) {
            guard !reportedFailure else { return }
            reportedFailure = true
            DispatchQueue.main.async { [onFailure] in
                onFailure(message)
            }
        }
    }
}
