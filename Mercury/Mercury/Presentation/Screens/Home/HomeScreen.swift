//
//  HomeScreen.swift
//  Mercury
//
//  Created by Codex on 31/03/26.
//

import SwiftUI

struct HomeScreen: View {
    let viewModel: HomeViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.title)
                            .font(.largeTitle.bold())
                            .accessibilityIdentifier("home.title")

                        Text(viewModel.subtitle)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("home.subtitle")
                    }
                    .padding(.vertical, 8)
                }

                Section("Feed Modes") {
                    ForEach(viewModel.feedModes) { mode in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode.title)
                                .font(.headline)
                            Text(mode.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Sample Articles") {
                    ForEach(viewModel.featuredArticles) { article in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(article.title)
                                .font(.headline)
                            Text("\(article.sourceName) • \(article.category ?? "Uncategorized")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let summaryShort = article.summaryShort {
                                Text(summaryShort)
                                    .font(.body)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Mercury")
        }
    }
}

#Preview {
    HomeScreen(viewModel: HomeViewModel())
}
