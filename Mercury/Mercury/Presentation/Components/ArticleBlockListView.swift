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
        .tint(.accentColor)
        .textSelection(.enabled)
        .accessibilityIdentifier("article.detail.body.native")
    }

    @ViewBuilder
    private func view(for block: ArticleBlock) -> some View {
        switch block {
        case .paragraph(let text):
            Text(text)
                .font(.body)
                .lineSpacing(4)
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
                            .fill(Color.secondary.opacity(0.12))
                            .frame(height: 220)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        Rectangle()
                            .fill(Color.secondary.opacity(0.12))
                            .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                            .frame(height: 180)
                    @unknown default:
                        Rectangle().fill(Color.secondary.opacity(0.12))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
                )
                .accessibilityLabel(alt ?? "")
                if let alt, alt.isEmpty == false {
                    Text(alt)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .list(let ordered, let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(ordered ? "\(index + 1)." : "•")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(item)
                            .font(.body)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, 4)
        case .quote(let text):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.opacity(0.7))
                    .frame(width: 4)
                Text(text)
                    .font(.title3.italic())
                    .foregroundStyle(.primary)
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
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private static func headingFont(level: Int) -> Font {
        switch level {
        case 1: return .title
        case 2: return .title2
        case 3: return .title3
        case 4: return .headline
        default: return .subheadline
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
