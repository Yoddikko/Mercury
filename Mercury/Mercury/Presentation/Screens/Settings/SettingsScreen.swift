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
/// The screen owns its `SettingsViewModel` and reads the live
/// `ModelContext` from the environment to bind directly to
/// `UserPreferencesService`. Today there is a single section — Article
/// rendering — but the layout is structured so further toggles can be
/// added without restructuring the screen.
struct SettingsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: SettingsViewModel
    @StateObject private var feedSourcesViewModel: FeedSourcesViewModel
    private let usesInjectedViewModel: Bool

    init() {
        // The "real" view models are built in `onAppear` because the
        // environment is not available during `init`. The placeholder
        // here is replaced before the user can interact with anything.
        _viewModel = StateObject(
            wrappedValue: SettingsViewModel(
                service: UserPreferencesService(
                    modelContext: ModelContext(SettingsScreen.placeholderContainer)
                )
            )
        )
        _feedSourcesViewModel = StateObject(
            wrappedValue: FeedSourcesViewModel(
                service: UserPreferencesService(
                    modelContext: ModelContext(SettingsScreen.placeholderContainer)
                )
            )
        )
        self.usesInjectedViewModel = false
    }

    /// Preview / test seam — accepts fully-built view models so the
    /// screen can be exercised without a SwiftData stack.
    init(viewModel: SettingsViewModel, feedSourcesViewModel: FeedSourcesViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _feedSourcesViewModel = StateObject(wrappedValue: feedSourcesViewModel)
        self.usesInjectedViewModel = true
    }

    var body: some View {
        Form {
            articleRendererSection
            feedSourcesSection
            if let message = viewModel.lastErrorMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("settings.error")
                }
            }
        }
        .navigationTitle(Self.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if usesInjectedViewModel == false {
                rebindToLiveContext()
            }
            viewModel.load()
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
                .navigationTitle(Self.feedSourcesTitle)
                .navigationBarTitleDisplayMode(.inline)
            } label: {
                Text(Self.feedSourcesTitle)
                    .accessibilityIdentifier("settings.feed_sources")
            }
        } header: {
            Text(Self.feedSourcesSectionHeader)
        } footer: {
            Text(Self.feedSourcesSectionFooter)
        }
    }

    private var articleRendererSection: some View {
        Section {
            Picker(
                Self.rendererPickerLabel,
                selection: Binding(
                    get: { viewModel.articleRenderer },
                    set: { viewModel.updateArticleRenderer($0) }
                )
            ) {
                ForEach(ArticleRendererMode.allCases, id: \.self) { mode in
                    Text(mode.localizedTitle).tag(mode)
                }
            }
            .pickerStyle(.inline)
            .accessibilityIdentifier("settings.renderer.picker")

            Text(viewModel.articleRenderer.localizedDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text(Self.rendererSectionTitle)
        } footer: {
            Text(Self.rendererSectionFooter)
        }
    }

    private func rebindToLiveContext() {
        // Swap the placeholder context for the one provided by the
        // environment. The view models are classes so reassigning their
        // service is safe.
        let liveService = UserPreferencesService(modelContext: modelContext)
        viewModel.replaceService(liveService)
        feedSourcesViewModel.replaceService(liveService)
    }

    // MARK: - Localized copy

    private static var title: String {
        String(localized: "settings.title", defaultValue: "Settings")
    }

    private static var rendererSectionTitle: String {
        String(localized: "settings.section.renderer.title", defaultValue: "Article rendering")
    }

    private static var rendererSectionFooter: String {
        String(
            localized: "settings.section.renderer.footer",
            defaultValue: "Choose how article bodies are displayed on the detail screen."
        )
    }

    private static var rendererPickerLabel: String {
        String(localized: "settings.section.renderer.picker", defaultValue: "Renderer")
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
            defaultValue: "Choose the regions and outlets that feed the Home stream."
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
