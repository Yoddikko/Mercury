//
//  MercuryTests.swift
//  MercuryTests
//
//  Created by Ale on 31/03/26.
//

import Foundation
import Testing
@testable import Mercury

struct MercuryTests {
    @Test @MainActor
    func homeViewModelStartsInIdleState() async throws {
        let viewModel = HomeViewModel(
            feedRefreshAction: { _ in
                RSSFeedBatchResult(
                    checkedAt: .now,
                    groupMode: .mainOutlets,
                    selectedRegion: nil,
                    checks: [],
                    deduplicatedArticles: []
                )
            },
            isDeveloperModeEnabled: false
        )

        #expect(viewModel.title == "Mercurio")
        #expect(viewModel.state == .idle)
        #expect(viewModel.isRefreshing == false)
        #expect(viewModel.hasArticles == false)
    }
}
