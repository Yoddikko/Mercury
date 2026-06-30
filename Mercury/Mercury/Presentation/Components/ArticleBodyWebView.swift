//
//  ArticleBodyWebView.swift
//  Mercury
//
//  Created by Codex on 30/06/26.
//

import SwiftUI
@preconcurrency import WebKit

/// SwiftUI wrapper around a `WKWebView` that renders sanitized article
/// HTML inline in the detail screen (issue #57).
///
/// The wrapper owns three responsibilities:
///
/// 1. Inject a system-font, dark-mode-aware `<style>` block around the
///    article body so the rendered output matches the surrounding
///    SwiftUI typography rather than the outlet's stylesheet.
/// 2. Disable the WebView's own scroll axis and report its
///    `document.body.scrollHeight` upward via a `@Binding<CGFloat>` so
///    the outer `ScrollView` owns the scroll and the WebView sizes to
///    its intrinsic content height.
/// 3. Open `<a>` taps in the platform browser instead of in-place, so
///    article navigation cannot trap the user inside the WebView.
///
/// Sanitization is the caller's responsibility (see
/// `ArticleHTMLSanitizer`). The wrapper assumes its input is already
/// safe to render.
struct ArticleBodyWebView: UIViewRepresentable {
    let html: String
    @Binding var contentHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(contentHeight: $contentHeight)
    }

    func makeUIView(context: Context) -> WKWebView {
        let userScript = WKUserScript(
            source: Self.heightObserverScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )

        let userContent = WKUserContentController()
        userContent.addUserScript(userScript)
        userContent.add(context.coordinator, name: Coordinator.messageName)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContent
        configuration.dataDetectorTypes = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        webView.loadHTMLString(Self.wrap(html), baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastRenderedHTML != html {
            context.coordinator.lastRenderedHTML = html
            webView.loadHTMLString(Self.wrap(html), baseURL: nil)
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration
            .userContentController
            .removeScriptMessageHandler(forName: Coordinator.messageName)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        static let messageName = "heightChanged"

        @Binding var contentHeight: CGFloat
        var lastRenderedHTML: String = ""

        init(contentHeight: Binding<CGFloat>) {
            _contentHeight = contentHeight
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == Self.messageName,
                  let raw = message.body as? NSNumber else { return }
            let next = CGFloat(raw.doubleValue)
            guard next.isFinite, next > 0 else { return }
            Task { @MainActor in
                if abs(contentHeight - next) > 0.5 {
                    contentHeight = next
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // The initial `loadHTMLString` is a `.other` navigation; let it
            // through. Any `.linkActivated` opens externally so the user
            // never gets stuck inside the embedded WebView.
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)
            Task { @MainActor in
                UIApplication.shared.open(url)
            }
        }
    }

    // MARK: - HTML wrapping

    private static func wrap(_ body: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
        <style>\(stylesheet)</style>
        </head>
        <body>\(body)</body>
        </html>
        """
    }

    private static let stylesheet: String = """
        :root { color-scheme: light dark; }
        html, body { margin: 0; padding: 0; background: transparent; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
            font-size: 17px;
            line-height: 1.55;
            color: #111;
            -webkit-text-size-adjust: 100%;
            word-wrap: break-word;
            overflow-wrap: break-word;
        }
        @media (prefers-color-scheme: dark) {
            body { color: #f2f2f2; }
            blockquote { border-left-color: rgba(255,255,255,0.25); color: rgba(255,255,255,0.75); }
            a { color: #4ea3ff; }
        }
        p { margin: 0 0 16px 0; }
        h1, h2, h3, h4, h5, h6 {
            margin: 24px 0 8px 0;
            font-weight: 600;
            line-height: 1.3;
        }
        ul, ol { margin: 0 0 16px 1.25em; padding: 0; }
        li { margin-bottom: 6px; }
        a { color: #007aff; text-decoration: none; }
        img, figure, video {
            max-width: 100%;
            height: auto;
            display: block;
            margin: 16px auto;
            border-radius: 8px;
        }
        figcaption {
            font-size: 14px;
            color: rgba(127,127,127,1);
            text-align: center;
            margin-top: 6px;
        }
        blockquote {
            margin: 16px 0;
            padding: 4px 0 4px 12px;
            border-left: 3px solid rgba(0,0,0,0.2);
            color: rgba(0,0,0,0.65);
            font-style: italic;
        }
        pre, code {
            font-family: ui-monospace, "SF Mono", SFMono-Regular, Menlo, monospace;
            font-size: 15px;
        }
        pre {
            background: rgba(127,127,127,0.12);
            padding: 12px;
            border-radius: 8px;
            overflow-x: auto;
        }
        """

    private static let heightObserverScript: String = """
        (function() {
          function reportHeight() {
            const h = Math.max(
              document.body.scrollHeight,
              document.documentElement.scrollHeight
            );
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.heightChanged) {
              window.webkit.messageHandlers.heightChanged.postMessage(h);
            }
          }
          reportHeight();
          // Re-report when images load (height grows as they paint).
          window.addEventListener('load', reportHeight);
          document.querySelectorAll('img').forEach(function(img) {
            if (!img.complete) { img.addEventListener('load', reportHeight); }
            img.addEventListener('error', reportHeight);
          });
          if (typeof ResizeObserver !== 'undefined') {
            const ro = new ResizeObserver(function() { reportHeight(); });
            ro.observe(document.body);
          }
        })();
        """
}
