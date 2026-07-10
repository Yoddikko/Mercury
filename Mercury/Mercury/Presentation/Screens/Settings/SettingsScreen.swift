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
    @StateObject private var interestsViewModel: InterestsViewModel
    @StateObject private var aiProviderViewModel = DeveloperAIProviderSettingsViewModel()
    private let usesInjectedViewModel: Bool

    init() {
        // The "real" view models are built in `onAppear` because the
        // environment is not available during `init`. The placeholders
        // here are replaced before the user can interact with anything.
        let placeholderService = UserPreferencesService(
            modelContext: ModelContext(SettingsScreen.placeholderContainer)
        )
        _feedSourcesViewModel = StateObject(
            wrappedValue: FeedSourcesViewModel(service: placeholderService)
        )
        _interestsViewModel = StateObject(
            wrappedValue: InterestsViewModel(service: placeholderService)
        )
        self.usesInjectedViewModel = false
    }

    /// Preview / test seam — accepts a fully-built view model so the
    /// screen can be exercised without a SwiftData stack.
    init(feedSourcesViewModel: FeedSourcesViewModel) {
        _feedSourcesViewModel = StateObject(wrappedValue: feedSourcesViewModel)
        _interestsViewModel = StateObject(
            wrappedValue: InterestsViewModel(
                service: UserPreferencesService(
                    modelContext: ModelContext(SettingsScreen.placeholderContainer)
                )
            )
        )
        self.usesInjectedViewModel = true
    }

    var body: some View {
        Form {
            feedSourcesSection
            interestsSection
            aiSection
            aboutSection
        }
        .paperScreen()
        .navigationTitle(Self.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if usesInjectedViewModel == false {
                rebindToLiveContext()
            }
            feedSourcesViewModel.load()
            interestsViewModel.load()
            await aiProviderViewModel.load()
        }
        .accessibilityIdentifier("settings.screen")
    }

    /// Interests behind the "Per te" feed (issue #136): same shared
    /// editor as the onboarding step, reachable at any time.
    private var interestsSection: some View {
        Section {
            NavigationLink {
                Form {
                    InterestsEditor(
                        viewModel: interestsViewModel,
                        footerText: Self.interestsFooter
                    )
                }
                .paperScreen()
                .navigationTitle(Self.interestsTitle)
                .navigationBarTitleDisplayMode(.inline)
            } label: {
                HStack(spacing: 8) {
                    Text(Self.interestsTitle)
                        .font(.paperCallout)
                        .foregroundStyle(Color.paperInk)
                    Spacer()
                    Text("\(interestsViewModel.selected.count)")
                        .font(.paperMeta)
                        .foregroundStyle(Color.paperRule)
                }
            }
            .accessibilityIdentifier("settings.interests")
        } header: {
            Text(Self.interestsSectionHeader.uppercased())
                .font(.paperBadge)
                .foregroundStyle(Color.paperRule)
        } footer: {
            Text(Self.interestsSectionFooter)
                .font(.paperMeta)
                .foregroundStyle(Color.paperRule)
        }
    }

    /// Entry point for the consumer AI provider setup (issue #115): the
    /// row shows the current provider and its readiness inline so the
    /// user knows the AI state without drilling in.
    private var aiSection: some View {
        Section {
            NavigationLink {
                AIProviderSettingsScreen(viewModel: aiProviderViewModel)
            } label: {
                HStack(spacing: 8) {
                    Text(AIProviderSettingsScreen.title)
                        .font(.paperCallout)
                        .foregroundStyle(Color.paperInk)
                    Spacer()
                    Text(aiProviderViewModel.activeProviderID.displayName)
                        .font(.paperMeta)
                        .foregroundStyle(Color.paperRule)
                }
            }
            .accessibilityIdentifier("settings.ai")
        } header: {
            Text(Self.aiSectionHeader.uppercased())
                .font(.paperBadge)
                .foregroundStyle(Color.paperRule)
        } footer: {
            Text(Self.aiSectionFooter)
                .font(.paperMeta)
                .foregroundStyle(Color.paperRule)
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text(Self.versionLabel)
                    .font(.paperCallout)
                    .foregroundStyle(Color.paperInk)
                Spacer()
                Text(Self.appVersion)
                    .font(.paperMeta)
                    .foregroundStyle(Color.paperRule)
                    .accessibilityIdentifier("settings.about.version")
            }
        } header: {
            Text(Self.aboutSectionHeader.uppercased())
                .font(.paperBadge)
                .foregroundStyle(Color.paperRule)
        }
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
        interestsViewModel.replaceService(liveService)
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

    private static var interestsTitle: String {
        String(localized: "settings.interests.title", defaultValue: "Interests")
    }

    private static var interestsSectionHeader: String {
        String(
            localized: "settings.section.interests.header",
            defaultValue: "Personalization"
        )
    }

    private static var interestsSectionFooter: String {
        String(
            localized: "settings.section.interests.footer",
            defaultValue: "The \"For You\" feed ranks the news against these interests."
        )
    }

    private static var interestsFooter: String {
        String(
            localized: "settings.interests.footer",
            defaultValue: "Changes apply the next time the \"For You\" feed refreshes (pull down or wait for the countdown)."
        )
    }

    private static var aiSectionHeader: String {
        String(localized: "settings.section.ai.header", defaultValue: "Artificial intelligence")
    }

    private static var aiSectionFooter: String {
        String(
            localized: "settings.section.ai.footer",
            defaultValue: "Summaries and topic grouping use the configured provider."
        )
    }

    private static var aboutSectionHeader: String {
        String(localized: "settings.section.about.header", defaultValue: "About")
    }

    private static var versionLabel: String {
        String(localized: "settings.about.version", defaultValue: "Version")
    }

    private static var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
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
