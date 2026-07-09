//
//  FeedSourcesPicker.swift
//  Mercury
//
//  Created by Codex on 01/07/26.
//

import SwiftUI

/// Reusable region + per-source picker.
///
/// Rendered inline in both the first-launch onboarding screen and the
/// Settings screen so both surfaces share the same UI and view model.
/// See `docs/features/SETTINGS.md` § Feed sources.
struct FeedSourcesPicker: View {
    @ObservedObject var viewModel: FeedSourcesViewModel
    @State private var expandedRegions: Set<String> = []

    var body: some View {
        if viewModel.isSingleRegionCatalog, let only = viewModel.regions.first {
            // Italy-only scope (issue #102): with a single region there is
            // nothing to choose at region level — list the outlets
            // directly. The region itself is auto-enabled by the view
            // model on load.
            Section {
                ForEach(viewModel.outlets(for: only.region)) { outlet in
                    Toggle(isOn: Binding(
                        get: { outlet.isEnabled },
                        set: { _ in viewModel.toggleSource(outlet.source) }
                    )) {
                        Text(outlet.source.outletName)
                            .font(.callout)
                    }
                    .accessibilityIdentifier("feed_sources.source.\(outlet.source.id)")
                }
            } header: {
                Text(Self.singleRegionSectionLabel)
            }
        } else {
            multiRegionBody
        }

        if let message = viewModel.lastErrorMessage {
            Section {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("feed_sources.error")
            }
        }
    }

    @ViewBuilder
    private var multiRegionBody: some View {
        ForEach(viewModel.regions) { selection in
            Section {
                Toggle(isOn: Binding(
                    get: { selection.isEnabled },
                    set: { _ in viewModel.toggleRegion(selection.region) }
                )) {
                    HStack {
                        Text(selection.region.fallbackDisplayName)
                            .font(.body)
                        Spacer()
                        Text(Self.outletCountLabel(selection.outletCount))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("feed_sources.region.\(selection.region.rawValue)")

                if selection.isEnabled {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedRegions.contains(selection.region.rawValue) },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedRegions.insert(selection.region.rawValue)
                                } else {
                                    expandedRegions.remove(selection.region.rawValue)
                                }
                            }
                        )
                    ) {
                        ForEach(viewModel.outlets(for: selection.region)) { outlet in
                            Toggle(isOn: Binding(
                                get: { outlet.isEnabled },
                                set: { _ in viewModel.toggleSource(outlet.source) }
                            )) {
                                Text(outlet.source.outletName)
                                    .font(.callout)
                            }
                            .accessibilityIdentifier("feed_sources.source.\(outlet.source.id)")
                        }
                    } label: {
                        Text(Self.outletsSectionLabel)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private static func outletCountLabel(_ count: Int) -> String {
        let format = String(
            localized: "feed_sources.region.outlets_count",
            defaultValue: "%lld outlets"
        )
        return String(format: format, locale: .current, count)
    }

    private static var outletsSectionLabel: String {
        String(
            localized: "feed_sources.region.outlets_section",
            defaultValue: "Outlets in this region"
        )
    }

    private static var singleRegionSectionLabel: String {
        String(
            localized: "feed_sources.single_region.outlets_section",
            defaultValue: "Italian outlets"
        )
    }
}
