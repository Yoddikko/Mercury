//
//  MercuryApp.swift
//  Mercury
//
//  Created by Ale on 31/03/26.
//

import SwiftUI
import SwiftData

@main
struct MercuryApp: App {
    private let dependencyContainer = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            AppRouter(dependencyContainer: dependencyContainer).rootView()
        }
        .modelContainer(for: [StoredArticle.self])
    }
}
