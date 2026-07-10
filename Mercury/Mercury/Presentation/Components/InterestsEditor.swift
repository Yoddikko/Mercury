//
//  InterestsEditor.swift
//  Mercury
//
//  Created by Claude on 10/07/26.
//

import SwiftUI

/// Shared interests editor (issues #133, #136): suggested chips plus
/// free-text custom entries, persisted on every toggle through
/// `InterestsViewModel`. Embedded as Form sections by the onboarding
/// interests step and the Settings → Interests subscreen.
struct InterestsEditor: View {
    @ObservedObject var viewModel: InterestsViewModel
    /// Context-specific footer under the custom-entry section: the
    /// onboarding mentions the upcoming provider step, Settings says
    /// when edits take effect.
    let footerText: String

    var body: some View {
        Section {
            interestChips(InterestsViewModel.suggestions)
        }
        Section {
            HStack(spacing: 8) {
                TextField(
                    InterestsViewModel.customPlaceholder,
                    text: $viewModel.customInput
                )
                .font(.paperCallout)
                .onSubmit { viewModel.addCustomInterest() }
                .accessibilityIdentifier("interests.custom_field")
                Button {
                    viewModel.addCustomInterest()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.paperSecondary)
                .accessibilityIdentifier("interests.add")
            }
            if viewModel.customInterests.isEmpty == false {
                interestChips(viewModel.customInterests)
            }
        } footer: {
            Text(footerText)
                .font(.paperMeta)
                .foregroundStyle(Color.paperRule)
        }
        if let message = viewModel.lastErrorMessage {
            Section {
                Text(message)
                    .font(.paperMeta)
                    .foregroundStyle(Color.paperError)
            }
        }
    }

    /// Chip grid: selected = ink block, unselected = hairline box.
    private func interestChips(_ interests: [String]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 110), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(interests, id: \.self) { interest in
                let isOn = viewModel.isSelected(interest)
                Button {
                    viewModel.toggle(interest)
                } label: {
                    Text(interest)
                        .font(.paperBadge)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(isOn ? Color.paperBackground : Color.paperInk)
                        .background(isOn ? Color.paperInk : Color.clear)
                        .overlay(Rectangle().stroke(Color.paperInk, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isSelected] : [])
                .accessibilityIdentifier("interests.chip.\(interest)")
            }
        }
        .padding(.vertical, 4)
    }
}
