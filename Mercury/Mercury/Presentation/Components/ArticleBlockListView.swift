//
//  ArticleBlockListView.swift
//  Mercury
//
//  Created by Codex on 30/06/26.
//

import SwiftUI

/// Renders a `[ArticleBlock]` sequence with native SwiftUI views (issue
/// #59). Counterpart to `ArticleBodyWebView` for the `.native` rendering
/// mode.
///
/// The view leaves spacing decisions to the surrounding `VStack`; each
/// block returns its own root view sized to its intrinsic content.
struct ArticleBlockListView: View {
    let blocks: [ArticleBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(blocks) { block in
                view(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("article.detail.body.native")
    }

    @ViewBuilder
    private func view(for block: ArticleBlock) -> some View {
        switch block {
        case .paragraph(let text):
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        case .heading(let level, let text):
            Text(text)
                .font(Self.headingFont(level: level))
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        case .image(let url, let alt):
            VStack(alignment: .leading, spacing: 4) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.secondary.opacity(0.12))
                            .frame(height: 180)
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
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel(alt ?? "")
                if let alt, alt.isEmpty == false {
                    Text(alt)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        case .list(let ordered, let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(ordered ? "\(index + 1)." : "•")
                            .font(.body.weight(.semibold))
                            .accessibilityHidden(true)
                        Text(item)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case .quote(let text):
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(Color.secondary)
                    .frame(width: 3)
                Text(text)
                    .font(.body.italic())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 4)
        case .code(let body, _):
            Text(body)
                .font(.system(.callout, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .textSelection(.enabled)
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
}
