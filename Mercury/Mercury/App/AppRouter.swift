//
//  AppRouter.swift
//  Mercury
//
//  Created by Codex on 31/03/26.
//

import SwiftUI

struct AppRouter {
    let dependencyContainer: DependencyContainer

    @ViewBuilder
    func rootView() -> some View {
        HomeScreen(viewModel: dependencyContainer.makeHomeViewModel())
    }
}
