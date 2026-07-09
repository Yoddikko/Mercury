//
//  ArticleBlockListView.swift
//  Mercury
//
//  Created by Codex on 30/06/26.
//

import SwiftUI

/// Renders a `[ArticleBlock]` sequence with native SwiftUI views.
///
/// Introduced in issue #59 as the opt-in native counterpart to a
/// legacy `WKWebView` renderer; the WebView path was removed in
/// issue #83 and this view is now the sole reader for article
/// bodies.
///
/// The view leaves spacing decisions to the surrounding `VStack`; each
/// block returns its own root view sized to its intrinsic content.
struct ArticleBlockListView: View {
    let blocks: [ArticleBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(blocks) { block in
                view(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(Color.paperInk)
        .foregroundStyle(Color.paperInk)
        .textSelection(.enabled)
        .accessibilityIdentifier("article.detail.body.native")
    }

    @ViewBuilder
    private func view(for block: ArticleBlock) -> some View {
        switch block {
        case .paragraph(let text):
            Text(text)
                .font(.paperBody)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        case .heading(let level, let text):
            Text(text)
                .font(Self.headingFont(level: level))
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Self.headingTopPadding(level: level))
                .padding(.bottom, 2)
        case .image(let url, let alt):
            VStack(alignment: .leading, spacing: 6) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.paperRule.opacity(0.12))
                            .frame(height: 220)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        Rectangle()
                            .fill(Color.paperRule.opacity(0.12))
                            .overlay(Image(systemName: "photo").foregroundStyle(Color.paperRule))
                            .frame(height: 180)
                    @unknown default:
                        Rectangle().fill(Color.paperRule.opacity(0.12))
                    }
                }
                .overlay(Rectangle().stroke(Color.paperRule.opacity(0.35), lineWidth: 0.8))
                .accessibilityLabel(alt ?? "")
                if let alt, alt.isEmpty == false {
                    // Print-style caption: mono, like a photo credit line.
                    Text(alt)
                        .font(.paperMeta)
                        .foregroundStyle(Color.paperRule)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .list(let ordered, let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(ordered ? "\(index + 1)." : "•")
                            .font(.paperBody.weight(.semibold))
                            .foregroundStyle(Color.paperRule)
                            .accessibilityHidden(true)
                        Text(item)
                            .font(.paperBody)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, 4)
        case .quote(let text):
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Color.paperInk)
                    .frame(width: 2)
                Text(text)
                    .font(.system(.title3, design: .serif).italic())
                    .foregroundStyle(Color.paperInk)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        case .code(let body, _):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(body)
                    .font(.system(.callout, design: .monospaced))
                    .padding(12)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.paperRule.opacity(0.12))
            .overlay(Rectangle().stroke(Color.paperRule.opacity(0.35), lineWidth: 0.8))
        }
    }

    private static func headingFont(level: Int) -> Font {
        switch level {
        case 1: return .system(.title, design: .serif)
        case 2: return .system(.title2, design: .serif)
        case 3: return .system(.title3, design: .serif)
        case 4: return .system(.headline, design: .serif)
        default: return .system(.subheadline, design: .serif)
        }
    }

    /// Editorial rhythm: h1/h2 open new sections and deserve extra
    /// breathing room; h3–h6 sit closer to surrounding prose.
    private static func headingTopPadding(level: Int) -> CGFloat {
        switch level {
        case 1, 2: return 20
        case 3: return 14
        default: return 10
        }
    }
}
