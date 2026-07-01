//
//  AppRouter.swift
//  Mercury
//
//  Created by Codex on 31/03/26.
//  Updated to own the Home view-model lifecycle on 25/06/26.
//

import SwiftUI

/// Lightweight composition root that owns the screen-level view models so
/// SwiftUI can keep them alive across the root view's lifecycle.
///
/// Note: this stays intentionally thin — full DI orchestration is tracked
/// by separate issues that will introduce the repository/use-case layers.
struct AppRouter: View {
    let dependencyContainer: DependencyContainer

    @StateObject private var homeViewModel: HomeViewModel

    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
        _homeViewModel = StateObject(wrappedValue: dependencyContainer.makeHomeViewModel())
    }

    var body: some View {
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
