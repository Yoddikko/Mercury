//
//  DeveloperPlaygroundScreen.swift
//  Mercury
//
//  Created by Codex on 01/04/26.
//

#if DEBUG

import SwiftData
import SwiftUI

struct DeveloperPlaygroundScreen: View {
    let viewModel: DeveloperPlaygroundViewModel

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredArticle.createdAt, order: .reverse) private var storedArticles: [StoredArticle]

    @State private var selectedProviderID = DeveloperPlaygroundViewModel.defaultProviderID
    @State private var promptInput = ""
    @State private var simulationOutput = ""

    var body: some View {
        Form {
            Section {
                Text(viewModel.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("developer.playground.subtitle")
            }

            Section(viewModel.aiSimulationSectionTitle) {
                Picker(viewModel.providerLabel, selection: $selectedProviderID) {
                    ForEach(viewModel.providerOptions) { option in
                        Text(option.displayName).tag(option.id)
                    }
                }
                .accessibilityIdentifier("developer.playground.provider")

                TextField(viewModel.promptInputLabel, text: $promptInput, axis: .vertical)
                    .lineLimit(3...6)
                    .accessibilityIdentifier("developer.playground.prompt")

                Button(viewModel.runSimulationLabel) {
                    simulationOutput = viewModel.simulatedSummary(
                        prompt: promptInput,
                        providerID: selectedProviderID
                    )
                }
                .accessibilityIdentifier("developer.playground.run")

                if simulationOutput.isEmpty == false {
                    Text(simulationOutput)
                        .font(.callout)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("developer.playground.output")
                }
            }

            Section(viewModel.swiftDataSandboxSectionTitle) {
                Text(viewModel.storedDebugRecordsLabel(count: storedArticles.count))
                    .accessibilityIdentifier("developer.playground.count")

                HStack {
                    Button(viewModel.insertSampleRecordLabel) {
                        modelContext.insert(
                            viewModel.makeSampleStoredArticle(existingCount: storedArticles.count)
                        )
                    }
                    .accessibilityIdentifier("developer.playground.insert")

                    Button(viewModel.clearRecordsLabel, role: .destructive) {
                        clearStoredArticles()
                    }
                    .accessibilityIdentifier("developer.playground.clear")
                }

                if storedArticles.isEmpty == false {
                    ForEach(storedArticles.prefix(5)) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                            Text(item.sourceName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle(viewModel.title)
        .accessibilityIdentifier("developer.playground.screen")
    }

    private func clearStoredArticles() {
        for article in storedArticles {
            modelContext.delete(article)
        }
    }
}

#Preview {
    NavigationStack {
        DeveloperPlaygroundScreen(viewModel: DeveloperPlaygroundViewModel())
    }
}

#endif
