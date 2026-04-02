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
    private let logger = AppLogger.shared

    init() {
        logger.info(
            "Application initialized",
            category: .system,
            service: "MercuryApp",
            metadata: ["developer_mode": "\(DeveloperMode.isEnabled)"]
        )
    }

    var body: some Scene {
        WindowGroup {
            AppRouter(dependencyContainer: dependencyContainer).rootView()
        }
        .modelContainer(
            for: [
                StoredArticle.self,
                ArticleEntity.self,
                ClusterEntity.self,
                UserPreferenceEntity.self,
                InteractionEntity.self
            ]
        )
    }
}
