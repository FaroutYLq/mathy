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

    /// Escape a LaTeX string for safe embedding in HTML/JS contexts.
    private func escapeForHTML(_ str: String) -> String {
        str.replacingOccurrences(of: "\\", with: "\\\\")
           .replacingOccurrences(of: "\"", with: "\\\"")
           .replacingOccurrences(of: "'", with: "\\'")
           .replacingOccurrences(of: "<", with: "\\x3c")
           .replacingOccurrences(of: ">", with: "\\x3e")
           .replacingOccurrences(of: "&", with: "\\x26")
           .replacingOccurrences(of: "`", with: "\\x60")
           .replacingOccurrences(of: "\n", with: "\\n")
           .replacingOccurrences(of: "\r", with: "\\r")
    }

    private func loadLatex(in webView: WKWebView) {
        let escaped = escapeForHTML(latex)

        // Try bundled HTML first
        if let htmlURL = Bundle.main.url(forResource: "latex_preview", withExtension: "html") {
            let baseURL = htmlURL.deletingLastPathComponent()
            do {
                var html = try String(contentsOf: htmlURL)
                html = html.replacingOccurrences(of: "{{LATEX}}", with: escaped)
                webView.loadHTMLString(html, baseURL: baseURL)
                return
            } catch {
                print("Failed to load bundled HTML: \(error)")
            }
        }

        // Fallback: inline HTML with CDN KaTeX
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
