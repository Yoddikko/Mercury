//
//  HomeScreen.swift
//  Mercury
//
//  Created by Codex on 31/03/26.
//

import SwiftUI

struct HomeScreen: View {
    let viewModel: HomeViewModel
#if DEBUG
    let developerPlaygroundViewModel: DeveloperPlaygroundViewModel
#endif

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

                Section(viewModel.feedModesSectionTitle) {
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

                Section(viewModel.sampleArticlesSectionTitle) {
                    ForEach(viewModel.featuredArticles) { article in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(article.title)
                                .font(.headline)
                            Text(
                                viewModel.articleMetadataLine(
                                    sourceName: article.sourceName,
                                    category: article.category
                                )
                            )
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
            .navigationTitle(viewModel.navigationTitle)
#if DEBUG
            .toolbar {
                if viewModel.isDeveloperModeEnabled {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            DeveloperPlaygroundScreen(viewModel: developerPlaygroundViewModel)
                        } label: {
                            Label(viewModel.developerToolsLabel, systemImage: "ladybug.fill")
                        }
                        .accessibilityIdentifier("home.developerTools")
                    }
                }
            }
#endif
        }
    }
}

#Preview {
#if DEBUG
    HomeScreen(
        viewModel: HomeViewModel(),
        developerPlaygroundViewModel: DeveloperPlaygroundViewModel()
    )
#else
    HomeScreen(viewModel: HomeViewModel())
#endif
}
