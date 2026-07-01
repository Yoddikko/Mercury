//
//  DependencyContainer.swift
//  Mercury
//
//  Created by Codex on 31/03/26.
//

import Foundation
import SwiftData

/// Lightweight composition root that builds the screen-level view models
/// and the shared infrastructure they depend on.
///
/// Today the container owns the application-wide `ModelContainer` so the
/// SwiftUI `.modelContainer` modifier and the SwiftData-backed
/// `ArticleRepository` consumed by `FetchHomeFeedUseCase` share the same
/// underlying store. Full DI orchestration (proper module boundaries,
/// scoped lifetimes) is intentionally out of scope until the feature set
/// justifies it.
struct DependencyContainer {
    let modelContainer: ModelContainer
    private let logger: AppLogger

    init(
        modelContainer: ModelContainer = DependencyContainer.makeDefaultModelContainer(),
        logger: AppLogger = .shared
    ) {
        self.modelContainer = modelContainer
        self.logger = logger
        logger.debug(
            "DependencyContainer initialized",
            category: .system,
            service: "DependencyContainer"
        )
    }

    @MainActor
    func makeHomeViewModel() -> HomeViewModel {
        logger.debug(
            "Building HomeViewModel with FetchHomeFeedUseCase",
            category: .system,
            service: "DependencyContainer"
        )
        let repository = SwiftDataArticleRepository(modelContainer: modelContainer)
        let useCase = LiveFetchHomeFeedUseCase(
            feedRefreshService: FeedRefreshService(),
            articleRepository: repository
        )
        return HomeViewModel(fetchHomeFeedUseCase: useCase)
    }

    /// Build the summarize closure consumed by `ArticleDetailViewModel`.
    ///
    /// Wires `AIService` (active provider + credentials) to
    /// `ArticleSummarizationService` and returns a `Sendable` closure the
    /// detail screen can invoke when the user taps the summary button. All
    /// side effects (provider call + SwiftData persistence) are internal so
    /// the presentation layer stays UI-only.
    @MainActor
    func makeArticleSummarize() -> @Sendable (Article) async throws -> AISummaryResult {
        let aiService = AIService()
        let container = modelContainer
        let service = ArticleSummarizationService(
            summarize: { content, requestID in
                try await aiService.summarizeArticle(content, requestID: requestID)
            },
            persist: { articleID, summary, requestID in
                let store = ArticleLocalStore(modelContainer: container)
                try await store.applySummary(
                    articleID: articleID,
                    summary: summary,
                    requestID: requestID
                )
            }
        )
        return { article in
            try await service.summarizeIfNeeded(article)
        }
    }

#if DEBUG
    @MainActor
    func makeDeveloperPlaygroundViewModel() -> DeveloperPlaygroundViewModel {
        DeveloperPlaygroundViewModel()
    }
#endif

    /// Builds the default production `ModelContainer` that backs both the
    /// SwiftUI environment and the repository layer.
    static func makeDefaultModelContainer() -> ModelContainer {
        do {
            return try ModelContainer(
                for: StoredArticle.self,
                ArticleEntity.self,
                ClusterEntity.self,
                UserPreferenceEntity.self,
                InteractionEntity.self
            )
        } catch {
            AppLogger.shared.error(
                "Failed to build default ModelContainer",
                category: .system,
                service: "DependencyContainer",
                metadata: ["error": String(describing: error)]
            )
            fatalError("Unable to construct the application ModelContainer: \(error)")
        }
    }
}
