import SwiftUI
import WebKit

struct LaTeXRenderView: NSViewRepresentable {
    let latex: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        loadLatex(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        loadLatex(in: webView)
    }

    private func loadLatex(in webView: WKWebView) {
        // Try bundled HTML first
        if let htmlURL = Bundle.main.url(forResource: "latex_preview", withExtension: "html") {
            let baseURL = htmlURL.deletingLastPathComponent()
            do {
                var html = try String(contentsOf: htmlURL)
                let escaped = latex
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                html = html.replacingOccurrences(of: "{{LATEX}}", with: escaped)
                webView.loadHTMLString(html, baseURL: baseURL)
                return
            } catch {
                print("Failed to load bundled HTML: \(error)")
            }
        }

        // Fallback: inline HTML with CDN KaTeX
        let escaped = latex
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
            <script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
            <style>
                body {
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    margin: 0;
                    padding: 16px;
                    font-size: 20px;
                    background: transparent;
                }
                @media (prefers-color-scheme: dark) {
                    body { color: #e0e0e0; }
                }
            </style>
        </head>
        <body>
            <div id="math"></div>
            <script>
                katex.render("\(escaped)", document.getElementById("math"), {
                    throwOnError: false,
                    displayMode: true
                });
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}
