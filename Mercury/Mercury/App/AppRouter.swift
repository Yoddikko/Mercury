//
//  AppRouter.swift
//  Mercury
//
//  Created by Codex on 31/03/26.
//  Updated to own the Home view-model lifecycle on 25/06/26.
//  Onboarding gate added on 01/07/26 (issue #75).
//

import SwiftUI
import SwiftData

/// Lightweight composition root that owns the screen-level view models so
/// SwiftUI can keep them alive across the root view's lifecycle.
///
/// The router also gates the app behind the first-launch onboarding flow
/// (`OnboardingScreen`): when the persisted
/// `UserPreference.hasCompletedOnboarding` flag is `false` (default on
/// fresh install) the onboarding surface is shown; once the user taps
/// "Continue" the flag flips and `HomeScreen` is swapped in.
struct AppRouter: View {
    let dependencyContainer: DependencyContainer

    @Environment(\.modelContext) private var modelContext
    @StateObject private var homeViewModel: HomeViewModel
    @State private var hasCompletedOnboarding: Bool?

    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
        _homeViewModel = StateObject(wrappedValue: dependencyContainer.makeHomeViewModel())
    }

    var body: some View {
        content
            .task {
                if hasCompletedOnboarding == nil {
                    hasCompletedOnboarding = loadOnboardingState()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if hasCompletedOnboarding == false {
            OnboardingScreen(onCompleted: {
                hasCompletedOnboarding = true
            })
        } else {
#if DEBUG
            HomeScreen(
                viewModel: homeViewModel,
                developerPlaygroundViewModel: dependencyContainer.makeDeveloperPlaygroundViewModel(),
                articleSummarize: dependencyContainer.makeArticleSummarize()
            )
#else
            HomeScreen(
                viewModel: homeViewModel,
                articleSummarize: dependencyContainer.makeArticleSummarize()
            )
#endif
        }
    }

    private func loadOnboardingState() -> Bool {
        do {
            let service = UserPreferencesService(modelContext: modelContext)
            let preference = try service.loadPreferences()
            AppLogger.shared.debug(
                "AppRouter loaded onboarding state",
                category: .business,
                service: "AppRouter",
                metadata: ["has_completed_onboarding": "\(preference.hasCompletedOnboarding)"]
            )
            return preference.hasCompletedOnboarding
        } catch {
            AppLogger.shared.warn(
                "AppRouter failed to load onboarding state; showing onboarding",
                category: .business,
                service: "AppRouter",
                metadata: ["error": String(describing: error)]
            )
            return false
        }
    }
}
