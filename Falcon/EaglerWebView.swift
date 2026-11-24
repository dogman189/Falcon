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

enum FalconWebContent {
    case file(URL)
    case localServer(baseURL: URL)
}

/// Immersive wrapper that loads a selected bundled client in a browser-chrome-free WKWebView.
struct EaglerWebView: UIViewRepresentable {
    let content: FalconWebContent
    var snapshotter: WebViewSnapshotter?
    var webScale: Double = 1.0
    var backgroundUIColor: UIColor = UIColor(red: 11 / 255, green: 20 / 255, blue: 38 / 255, alpha: 1)
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
        webView.backgroundColor = backgroundUIColor
        webView.scrollView.backgroundColor = backgroundUIColor
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
        webView.pageZoom = webScale
        loadContent(in: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        snapshotter?.webView = uiView
        if uiView.pageZoom != webScale {
            uiView.pageZoom = webScale
        }
        if uiView.backgroundColor != backgroundUIColor {
            uiView.backgroundColor = backgroundUIColor
            uiView.scrollView.backgroundColor = backgroundUIColor
        }
    }

    private static func hexString(for color: UIColor) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }

    private func loadContent(in webView: WKWebView) {
        switch content {
        case let .file(fileURL):
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                assertionFailure("Missing bundled resource: \(fileURL.lastPathComponent)")
                let hex = Self.hexString(for: backgroundUIColor)
                let message = "<html><body style='background:\(hex);color:#fff;font-family:-apple-system'>Missing bundled client: \(fileURL.lastPathComponent)</body></html>"
                webView.loadHTMLString(message, baseURL: nil)
                return
            }
            #if DEBUG
            NSLog("[Falcon] Loading %@", fileURL.absoluteString)
            #endif
            webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
        case let .localServer(baseURL):
            webView.customUserAgent = "Mozilla/5.0 (iPad; CPU OS 27_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.2 Mobile/15E148 Safari/604.1"
            #if DEBUG
            NSLog("[Falcon] Loading local server %@", baseURL.absoluteString)
            #endif
            webView.load(URLRequest(url: baseURL))
        }
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
