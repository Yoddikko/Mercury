//
//  MercuryTests.swift
//  MercuryTests
//
//  Created by Ale on 31/03/26.
//

import Testing
@testable import Mercury

struct MercuryTests {
    @Test @MainActor func homeViewModelUsesMercuryScaffoldData() async throws {
        let viewModel = HomeViewModel()

        #expect(viewModel.title == "Mercury")
        #expect(viewModel.feedModes.count == 3)
        #expect(viewModel.featuredArticles.isEmpty == false)
    }
}
