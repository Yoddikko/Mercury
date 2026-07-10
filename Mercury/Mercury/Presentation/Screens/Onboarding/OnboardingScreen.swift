//
//  OnboardingScreen.swift
//  Mercury
//
//  Created by Codex on 01/07/26.
//  Four-step flow (intro, fonti, interessi, provider) on 10/07/26.
//

import SwiftUI
import SwiftData

/// First-launch onboarding (issues #75, #133): four paged steps —
/// Intro (zero I/O) → Fonti (outlet picker, NO article fetch) →
/// Interessi (chips + free text into `preferredTopics`) → Provider AI
/// (compact, skippable). The final Continue flips
/// `UserPreference.hasCompletedOnboarding`; the first feed refresh
/// fires only after that, exactly as before (issue #87 guarantee).
struct OnboardingScreen: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: FeedSourcesViewModel
    @StateObject private var interestsViewModel: InterestsViewModel
    @StateObject private var aiProviderViewModel = DeveloperAIProviderSettingsViewModel()
    @State private var step = 0
    private let usesInjectedViewModel: Bool
    let onCompleted: () -> Void

    private static let stepCount = 4

    init(onCompleted: @escaping () -> Void) {
        let placeholderService = UserPreferencesService(
            modelContext: ModelContext(OnboardingScreen.placeholderContainer)
        )
        _viewModel = StateObject(
            wrappedValue: FeedSourcesViewModel(service: placeholderService)
        )
        _interestsViewModel = StateObject(
            wrappedValue: InterestsViewModel(service: placeholderService)
        )
        self.usesInjectedViewModel = false
        self.onCompleted = onCompleted
    }

    /// Preview / test seam.
    init(viewModel: FeedSourcesViewModel, onCompleted: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _interestsViewModel = StateObject(
            wrappedValue: InterestsViewModel(
                service: UserPreferencesService(
                    modelContext: ModelContext(OnboardingScreen.placeholderContainer)
                )
            )
        )
        self.usesInjectedViewModel = true
        self.onCompleted = onCompleted
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                bottomBar
            }
            .paperScreen()
            .navigationTitle(Self.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if usesInjectedViewModel == false {
                    let liveService = UserPreferencesService(modelContext: modelContext)
                    viewModel.replaceService(
                        liveService,
                        cacheMaintenance: ArticleCacheMaintenanceService(modelContext: modelContext)
                    )
                    interestsViewModel.replaceService(liveService)
                }
                viewModel.load()
                interestsViewModel.load()
                await aiProviderViewModel.load()
            }
            .accessibilityIdentifier("onboarding.screen")
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: introStep
        case 1: sourcesStep
        case 2: interestsStep
        default: providerStep
        }
    }

    /// Step 1 — what the app is, in three lines. Zero I/O by design.
    private var introStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Text(Self.title)
                .font(.system(.largeTitle, design: .serif).bold())
                .foregroundStyle(Color.paperInk)
            PaperRule()
            introLine(icon: "newspaper", text: Self.introSources)
            introLine(icon: "square.stack.3d.up", text: Self.introTopics)
            introLine(icon: "sparkles", text: Self.introAI)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .accessibilityIdentifier("onboarding.step.intro")
    }

    private func introLine(icon: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.paperInk)
                .frame(width: 24)
            Text(text)
                .font(.paperBody)
                .foregroundStyle(Color.paperInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Step 2 — outlet selection. Persists preferences only: the first
    /// article fetch still fires after the final Continue (issue #87).
    private var sourcesStep: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Self.sourcesTitle)
                        .font(.paperTitle)
                        .foregroundStyle(Color.paperInk)
                    Text(Self.subtitle)
                        .font(.paperCallout)
                        .foregroundStyle(Color.paperRule)
                }
                .padding(.vertical, 8)
            }
            FeedSourcesPicker(viewModel: viewModel)
        }
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("onboarding.step.sources")
    }

    /// Step 3 — interests: suggested chips + free-text custom entries.
    private var interestsStep: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(InterestsViewModel.title)
                        .font(.paperTitle)
                        .foregroundStyle(Color.paperInk)
                    Text(InterestsViewModel.subtitle)
                        .font(.paperCallout)
                        .foregroundStyle(Color.paperRule)
                }
                .padding(.vertical, 8)
            }
            InterestsEditor(
                viewModel: interestsViewModel,
                footerText: InterestsViewModel.aiNote
            )
        }
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("onboarding.step.interests")
    }

    /// Step 4 — compact AI provider setup, skippable. Reuses the
    /// Settings surface and view model (issue #115).
    private var providerStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(Self.providerTitle)
                    .font(.paperTitle)
                    .foregroundStyle(Color.paperInk)
                Text(Self.providerSubtitle)
                    .font(.paperCallout)
                    .foregroundStyle(Color.paperRule)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            AIProviderSettingsScreen(viewModel: aiProviderViewModel)
        }
        .accessibilityIdentifier("onboarding.step.provider")
    }

    // MARK: - Navigation bar

    private var bottomBar: some View {
        VStack(spacing: 10) {
            PaperRule()
            HStack(spacing: 4) {
                ForEach(0..<Self.stepCount, id: \.self) { index in
                    Rectangle()
                        .fill(index == step ? Color.paperInk : Color.paperRule.opacity(0.35))
                        .frame(width: index == step ? 18 : 8, height: 3)
                }
            }
            .accessibilityHidden(true)
            HStack(spacing: 12) {
                if step > 0 {
                    Button {
                        step -= 1
                    } label: {
                        Text(Self.backLabel)
                    }
                    .buttonStyle(.paperSecondary)
                    .accessibilityIdentifier("onboarding.back")
                }
                Button {
                    advance()
                } label: {
                    Text(step == Self.stepCount - 1 ? Self.startLabel : Self.continueLabel)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.paperPrimary)
                .disabled(step == 1 && viewModel.hasAtLeastOneRegionEnabled == false)
                .accessibilityIdentifier("onboarding.continue")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    private func advance() {
        if step < Self.stepCount - 1 {
            step += 1
        } else {
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        let service = usesInjectedViewModel
            ? nil
            : UserPreferencesService(modelContext: modelContext)
        do {
            if let service {
                try service.updatePreferences(.init(hasCompletedOnboarding: true))
            }
            AppLogger.shared.info(
                "Onboarding completed",
                category: .business,
                service: "OnboardingScreen",
                metadata: ["interests": "\(interestsViewModel.selected.count)"]
            )
            onCompleted()
        } catch {
            AppLogger.shared.error(
                "Failed to persist onboarding completion",
                category: .database,
                service: "OnboardingScreen",
                metadata: ["error": String(describing: error)]
            )
        }
    }

    // MARK: - Localized copy

    private static var navigationTitle: String {
        String(localized: "onboarding.navigation.title", defaultValue: "Welcome")
    }

    private static var title: String {
        String(localized: "onboarding.title", defaultValue: "Choose your feed")
    }

    private static var sourcesTitle: String {
        String(localized: "onboarding.sources.title", defaultValue: "Your outlets")
    }

    private static var subtitle: String {
        String(
            localized: "onboarding.subtitle",
            defaultValue: "Pick the Italian outlets you want in your Home feed. You can change this later in Settings."
        )
    }

    private static var introSources: String {
        String(
            localized: "onboarding.intro.sources",
            defaultValue: "The main Italian outlets, cleaned up: articles only, no site clutter."
        )
    }

    private static var introTopics: String {
        String(
            localized: "onboarding.intro.topics",
            defaultValue: "The day's stories grouped by topic, so you see what matters at a glance."
        )
    }

    private static var introAI: String {
        String(
            localized: "onboarding.intro.ai",
            defaultValue: "AI summaries and a personalized feed, powered by the provider you choose."
        )
    }

    private static var providerTitle: String {
        String(localized: "onboarding.provider.title", defaultValue: "AI provider")
    }

    private static var providerSubtitle: String {
        String(
            localized: "onboarding.provider.subtitle",
            defaultValue: "Optional: unlocks summaries, AI topic grouping and the \"For you\" feed. You can set it up later in Settings."
        )
    }

    private static var backLabel: String {
        String(localized: "onboarding.back", defaultValue: "Back")
    }

    private static var startLabel: String {
        String(localized: "onboarding.start", defaultValue: "Start reading")
    }

    private static var continueLabel: String {
        String(localized: "onboarding.continue", defaultValue: "Continue")
    }

    // MARK: - Placeholder container

    private static let placeholderContainer: ModelContainer = {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        // ponytail: same rationale as SettingsScreen — an in-memory
        // schema for a single @Model never fails in practice; the live
        // environment context replaces the service before user
        // interaction.
        return try! ModelContainer(for: UserPreferenceEntity.self, configurations: configuration)
    }()
}
