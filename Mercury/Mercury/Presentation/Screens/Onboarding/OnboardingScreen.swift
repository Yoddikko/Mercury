//
//  OnboardingScreen.swift
//  Mercury
//
//  Created by Codex on 01/07/26.
//

import SwiftUI
import SwiftData

/// First-launch onboarding surface (issue #75).
///
/// The screen is intentionally lightweight: intro copy + the same
/// region/per-source picker used in Settings. The user confirms by
/// tapping "Continue", which flips
/// `UserPreference.hasCompletedOnboarding` to `true` and lets
/// `AppRouter` swap in `HomeScreen`.
struct OnboardingScreen: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: FeedSourcesViewModel
    private let usesInjectedViewModel: Bool
    let onCompleted: () -> Void

    init(onCompleted: @escaping () -> Void) {
        _viewModel = StateObject(
            wrappedValue: FeedSourcesViewModel(
                service: UserPreferencesService(
                    modelContext: ModelContext(OnboardingScreen.placeholderContainer)
                )
            )
        )
        self.usesInjectedViewModel = false
        self.onCompleted = onCompleted
    }

    /// Preview / test seam.
    init(viewModel: FeedSourcesViewModel, onCompleted: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.usesInjectedViewModel = true
        self.onCompleted = onCompleted
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Self.title)
                            .font(.paperTitle)
                            .foregroundStyle(Color.paperInk)
                        Text(Self.subtitle)
                            .font(.paperCallout)
                            .foregroundStyle(Color.paperRule)
                    }
                    .padding(.vertical, 8)
                }
                FeedSourcesPicker(viewModel: viewModel)
                Section {
                    Button {
                        completeOnboarding()
                    } label: {
                        Text(Self.continueLabel)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.paperPrimary)
                    .disabled(viewModel.hasAtLeastOneRegionEnabled == false)
                    .accessibilityIdentifier("onboarding.continue")
                } footer: {
                    Text(Self.footerLabel)
                        .font(.paperMeta)
                        .foregroundStyle(Color.paperRule)
                }
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
                }
                viewModel.load()
            }
            .accessibilityIdentifier("onboarding.screen")
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
                service: "OnboardingScreen"
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

    private static var subtitle: String {
        String(
            localized: "onboarding.subtitle",
            defaultValue: "Pick the Italian outlets you want in your Home feed. You can change this later in Settings."
        )
    }

    private static var continueLabel: String {
        String(localized: "onboarding.continue", defaultValue: "Continue")
    }

    private static var footerLabel: String {
        String(
            localized: "onboarding.footer",
            defaultValue: "You can revisit these choices from Settings → Feed sources."
        )
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
