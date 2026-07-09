//
//  SettingsScreen.swift
//  Mercury
//
//  Created by Codex on 30/06/26.
//

import SwiftUI
import SwiftData

/// Surface for app-behavior toggles (see `docs/features/SETTINGS.md`).
///
/// The screen owns its view models and reads the live `ModelContext`
/// from the environment to bind directly to `UserPreferencesService`.
/// Today the only surfaced section is Feed sources; the legacy article
/// renderer picker was removed in issue #83 when the reader went
/// native-only.
struct SettingsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var feedSourcesViewModel: FeedSourcesViewModel
    private let usesInjectedViewModel: Bool

    init() {
        // The "real" view model is built in `onAppear` because the
        // environment is not available during `init`. The placeholder
        // here is replaced before the user can interact with anything.
        _feedSourcesViewModel = StateObject(
            wrappedValue: FeedSourcesViewModel(
                service: UserPreferencesService(
                    modelContext: ModelContext(SettingsScreen.placeholderContainer)
                )
            )
        )
        self.usesInjectedViewModel = false
    }

    /// Preview / test seam — accepts a fully-built view model so the
    /// screen can be exercised without a SwiftData stack.
    init(feedSourcesViewModel: FeedSourcesViewModel) {
        _feedSourcesViewModel = StateObject(wrappedValue: feedSourcesViewModel)
        self.usesInjectedViewModel = true
    }

    var body: some View {
        Form {
            feedSourcesSection
        }
        .paperScreen()
        .navigationTitle(Self.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if usesInjectedViewModel == false {
                rebindToLiveContext()
            }
            feedSourcesViewModel.load()
        }
        .accessibilityIdentifier("settings.screen")
    }

    private var feedSourcesSection: some View {
        Section {
            NavigationLink {
                Form {
                    FeedSourcesPicker(viewModel: feedSourcesViewModel)
                }
                .paperScreen()
                .navigationTitle(Self.feedSourcesTitle)
                .navigationBarTitleDisplayMode(.inline)
            } label: {
                Text(Self.feedSourcesTitle)
                    .font(.paperCallout)
                    .foregroundStyle(Color.paperInk)
                    .accessibilityIdentifier("settings.feed_sources")
            }
        } header: {
            Text(Self.feedSourcesSectionHeader)
                .font(.paperBadge)
                .foregroundStyle(Color.paperRule)
        } footer: {
            Text(Self.feedSourcesSectionFooter)
                .font(.paperMeta)
                .foregroundStyle(Color.paperRule)
        }
    }

    private func rebindToLiveContext() {
        // Swap the placeholder context for the one provided by the
        // environment. The view model is a class so reassigning its
        // service is safe.
        let liveService = UserPreferencesService(modelContext: modelContext)
        feedSourcesViewModel.replaceService(
            liveService,
            cacheMaintenance: ArticleCacheMaintenanceService(modelContext: modelContext)
        )
    }

    // MARK: - Localized copy

    private static var title: String {
        String(localized: "settings.title", defaultValue: "Settings")
    }

    private static var feedSourcesTitle: String {
        String(
            localized: "settings.section.feed_sources.title",
            defaultValue: "Feed sources"
        )
    }

    private static var feedSourcesSectionHeader: String {
        String(
            localized: "settings.section.feed_sources.header",
            defaultValue: "Feed sources"
        )
    }

    private static var feedSourcesSectionFooter: String {
        String(
            localized: "settings.section.feed_sources.footer",
            defaultValue: "Choose the Italian outlets that feed the Home stream."
        )
    }

    // MARK: - Placeholder container

    /// In-memory SwiftData container used only to satisfy the
    /// non-throwing `init()` — the live environment context replaces
    /// the service before any user interaction.
    private static let placeholderContainer: ModelContainer = {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        // ponytail: force-try here is intentional — an in-memory schema
        // for a single @Model never fails in practice, and bubbling the
        // error up to a non-throwing initializer would require either a
        // factory or a fatalError. If this ever starts throwing, the
        // app is already in an unrecoverable state.
        return try! ModelContainer(for: UserPreferenceEntity.self, configurations: configuration)
    }()
}
