//
//  AIProviderSettingsScreen.swift
//  Mercury
//
//  Created by Claude on 09/07/26.
//

import SwiftUI

/// Consumer-grade AI provider configuration (issue #115), promoted out
/// of Developer Tools: pick the active provider, store its API key,
/// choose a model. Reuses `DeveloperAIProviderSettingsViewModel` as the
/// single source of provider-settings behavior — the Developer
/// Playground keeps its advanced diagnostics on the same view model
/// type. Paper design system throughout.
struct AIProviderSettingsScreen: View {
    @ObservedObject var viewModel: DeveloperAIProviderSettingsViewModel
    @State private var summaryLanguage = SummaryLanguagePreference.load()

    var body: some View {
        Form {
            providerSection
            credentialSection
            modelSection
            summariesSection
            feedbackSection
        }
        .paperScreen()
        .navigationTitle(Self.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .accessibilityIdentifier("settings.ai.screen")
    }

    // MARK: - Provider picker

    private var providerSection: some View {
        Section {
            ForEach(AIProviderID.allCases) { provider in
                Button {
                    guard viewModel.activeProviderID != provider else { return }
                    viewModel.activeProviderID = provider
                    Task { await viewModel.saveConfiguration() }
                } label: {
                    HStack(spacing: 8) {
                        Text(provider.displayName)
                            .font(.paperCallout)
                            .foregroundStyle(Color.paperInk)
                        Spacer()
                        PaperBadge(text: statusLabel(for: provider))
                        if viewModel.activeProviderID == provider {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.paperInk)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(viewModel.activeProviderID == provider ? [.isSelected] : [])
                .accessibilityIdentifier("settings.ai.provider.\(provider.rawValue)")
            }
        } header: {
            Text(Self.providerHeader.uppercased())
                .font(.paperBadge)
                .foregroundStyle(Color.paperRule)
        } footer: {
            Text(Self.providerFooter)
                .font(.paperMeta)
                .foregroundStyle(Color.paperRule)
        }
    }

    // MARK: - Credential

    @ViewBuilder
    private var credentialSection: some View {
        Section {
            if viewModel.activeProviderID == .ollama {
                TextField(Self.endpointPlaceholder, text: $viewModel.ollamaEndpoint)
                    .font(.system(.callout, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .accessibilityIdentifier("settings.ai.endpoint")
            } else {
                SecureField(Self.keyPlaceholder, text: activeTokenBinding)
                    .font(.system(.callout, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("settings.ai.key_field")

                Button {
                    Task { await viewModel.saveActiveCredential() }
                } label: {
                    if viewModel.isSavingCredentials {
                        ProgressView()
                    } else {
                        Text(Self.saveKeyLabel)
                    }
                }
                .buttonStyle(.paperSecondary)
                .disabled(viewModel.isSavingCredentials)
                .accessibilityIdentifier("settings.ai.save_key")
            }
        } header: {
            Text((viewModel.activeProviderID == .ollama ? Self.endpointHeader : Self.keyHeader).uppercased())
                .font(.paperBadge)
                .foregroundStyle(Color.paperRule)
        } footer: {
            if viewModel.activeProviderID != .ollama {
                Text(activeHasToken ? Self.keyPresentFooter : Self.keyMissingFooter)
                    .font(.paperMeta)
                    .foregroundStyle(Color.paperRule)
            }
        }
    }

    // MARK: - Model

    private var modelSection: some View {
        Section {
            // Placeholder shows the default that will be used when the
            // field stays empty (issue #119) — a key-only setup works.
            TextField(viewModel.activeProviderID.defaultModel, text: activeModelBinding)
                .font(.system(.callout, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("settings.ai.model_field")

            Button {
                Task { await viewModel.fetchAvailableModelsForActiveProvider() }
            } label: {
                if viewModel.isFetchingModels {
                    ProgressView()
                } else {
                    Text(Self.loadModelsLabel)
                }
            }
            .buttonStyle(.paperSecondary)
            .disabled(viewModel.isFetchingModels)
            .accessibilityIdentifier("settings.ai.load_models")

            ForEach(viewModel.availableModels, id: \.self) { model in
                Button {
                    activeModelBinding.wrappedValue = model
                    Task { await viewModel.saveConfiguration() }
                } label: {
                    HStack {
                        Text(model)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(Color.paperInk)
                            .lineLimit(1)
                        Spacer()
                        if activeModelBinding.wrappedValue == model {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.paperInk)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.ai.model.\(model)")
            }

            Button {
                Task { await viewModel.saveConfiguration() }
            } label: {
                if viewModel.isSavingConfiguration {
                    ProgressView()
                } else {
                    Text(Self.saveConfigurationLabel)
                }
            }
            .buttonStyle(.paperPrimary)
            .disabled(viewModel.isSavingConfiguration)
            .accessibilityIdentifier("settings.ai.save_configuration")
        } header: {
            Text(Self.modelHeader.uppercased())
                .font(.paperBadge)
                .foregroundStyle(Color.paperRule)
        }
    }

    // MARK: - Summaries

    /// Language of every AI summary (issue #129): defaults to the
    /// device language, user-overridable.
    private var summariesSection: some View {
        Section {
            Picker(Self.summaryLanguageLabel, selection: $summaryLanguage) {
                ForEach(SummaryLanguagePreference.allCases) { preference in
                    Text(preference.displayName)
                        .font(.paperCallout)
                        .tag(preference)
                }
            }
            .font(.paperCallout)
            .tint(Color.paperInk)
            .onChange(of: summaryLanguage) { _, newValue in
                newValue.save()
            }
            .accessibilityIdentifier("settings.ai.summary_language")
        } header: {
            Text(Self.summariesHeader.uppercased())
                .font(.paperBadge)
                .foregroundStyle(Color.paperRule)
        } footer: {
            Text(Self.summariesFooter)
                .font(.paperMeta)
                .foregroundStyle(Color.paperRule)
        }
    }

    // MARK: - Feedback

    @ViewBuilder
    private var feedbackSection: some View {
        if viewModel.statusMessage != nil || viewModel.errorMessage != nil {
            Section {
                if let status = viewModel.statusMessage {
                    Text(status)
                        .font(.paperMeta)
                        .foregroundStyle(Color.paperRule)
                        .accessibilityIdentifier("settings.ai.status")
                }
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.paperMeta)
                        .foregroundStyle(Color.paperError)
                        .accessibilityIdentifier("settings.ai.error")
                }
            }
            .listRowSeparator(.hidden)
        }
    }

    // MARK: - Active-provider bindings

    private var activeTokenBinding: Binding<String> {
        switch viewModel.activeProviderID {
        case .openAI: return $viewModel.openAITokenInput
        case .claude: return $viewModel.claudeTokenInput
        case .gemini: return $viewModel.geminiTokenInput
        case .ollama: return $viewModel.ollamaTokenInput
        case .deepSeek: return $viewModel.deepSeekTokenInput
        }
    }

    private var activeModelBinding: Binding<String> {
        switch viewModel.activeProviderID {
        case .openAI: return $viewModel.openAIModel
        case .claude: return $viewModel.claudeModel
        case .gemini: return $viewModel.geminiModel
        case .ollama: return $viewModel.ollamaModel
        case .deepSeek: return $viewModel.deepSeekModel
        }
    }

    private var activeHasToken: Bool {
        hasToken(viewModel.activeProviderID)
    }

    private func hasToken(_ provider: AIProviderID) -> Bool {
        switch provider {
        case .openAI: return viewModel.hasOpenAIToken
        case .claude: return viewModel.hasClaudeToken
        case .gemini: return viewModel.hasGeminiToken
        case .ollama: return viewModel.hasOllamaToken
        case .deepSeek: return viewModel.hasDeepSeekToken
        }
    }

    private func statusLabel(for provider: AIProviderID) -> String {
        if provider == .ollama || hasToken(provider) {
            return Self.statusReady
        }
        return Self.statusKeyMissing
    }

    // MARK: - Localized copy

    static var title: String {
        String(localized: "settings.ai.title", defaultValue: "AI provider")
    }

    private static var providerHeader: String {
        String(localized: "settings.ai.section.provider", defaultValue: "Provider")
    }

    private static var providerFooter: String {
        String(
            localized: "settings.ai.section.provider.footer",
            defaultValue: "The active provider powers article summaries and topic grouping."
        )
    }

    private static var keyHeader: String {
        String(localized: "settings.ai.section.key", defaultValue: "API key")
    }

    private static var endpointHeader: String {
        String(localized: "settings.ai.section.endpoint", defaultValue: "Endpoint")
    }

    private static var keyPlaceholder: String {
        String(localized: "settings.ai.key.placeholder", defaultValue: "Paste the API key")
    }

    private static var endpointPlaceholder: String {
        String(localized: "settings.ai.endpoint.placeholder", defaultValue: "http://localhost:11434")
    }

    private static var saveKeyLabel: String {
        String(localized: "settings.ai.key.save", defaultValue: "Save key")
    }

    private static var keyPresentFooter: String {
        String(
            localized: "settings.ai.key.present",
            defaultValue: "A key is stored for this provider. Saving replaces it."
        )
    }

    private static var keyMissingFooter: String {
        String(
            localized: "settings.ai.key.missing",
            defaultValue: "No key stored for this provider yet."
        )
    }

    private static var modelHeader: String {
        String(localized: "settings.ai.section.model", defaultValue: "Model")
    }

    private static var loadModelsLabel: String {
        String(localized: "settings.ai.model.load", defaultValue: "Load available models")
    }

    private static var saveConfigurationLabel: String {
        String(localized: "settings.ai.save", defaultValue: "Save configuration")
    }

    private static var summariesHeader: String {
        String(localized: "settings.ai.section.summaries", defaultValue: "Summaries")
    }

    private static var summaryLanguageLabel: String {
        String(localized: "settings.ai.summary_language.label", defaultValue: "Summary language")
    }

    private static var summariesFooter: String {
        String(
            localized: "settings.ai.section.summaries.footer",
            defaultValue: "Article and story summaries are written in this language."
        )
    }

    private static var statusReady: String {
        String(localized: "settings.ai.status.ready", defaultValue: "Ready")
    }

    private static var statusKeyMissing: String {
        String(localized: "settings.ai.status.key_missing", defaultValue: "Key missing")
    }
}
