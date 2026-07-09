//
//  DesignSystem.swift
//  Mercury
//
//  Created by Claude on 09/07/26.
//

import SwiftUI
import UIKit

/// "Paper" design system (issue #105) — the single source of visual
/// tokens for Mercurio's book/newspaper identity, derived from AirBook
/// for CrossPoint. See `docs/guidelines/DESIGN_SYSTEM.md`: following
/// these tokens is MANDATORY for every consumer-facing surface.
///
/// Two voices: serif (New York) for everything editorial, monospaced
/// for everything technical/metadata. One palette: warm ink on warm
/// paper, adaptive to dark mode, `paperError` as the only accent and
/// only for failures.

// MARK: - Color tokens

extension Color {
    /// Warm off-white page in light mode, near-black in dark mode.
    /// Every screen's full-bleed background.
    static let paperBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1)
            : UIColor(red: 0.976, green: 0.969, blue: 0.957, alpha: 1)
    })

    /// Primary "ink": warm near-black text, icons and hairline strokes.
    static let paperInk = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.91, green: 0.90, blue: 0.88, alpha: 1)
            : UIColor(red: 0.08, green: 0.07, blue: 0.06, alpha: 1)
    })

    /// Warm gray for secondary text and rules (dividers usually at
    /// `.opacity(0.35)`).
    static let paperRule = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.48, green: 0.46, blue: 0.44, alpha: 1)
            : UIColor(red: 0.50, green: 0.48, blue: 0.45, alpha: 1)
    })

    /// Muted amber — errors ONLY, never decorative.
    static let paperError = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.62, green: 0.44, blue: 0.16, alpha: 1)
            : UIColor(red: 0.48, green: 0.28, blue: 0.05, alpha: 1)
    })
}

// MARK: - Typography tokens

extension Font {
    /// Screen/article titles — serif, bold.
    static let paperTitle = Font.system(.title2, design: .serif).bold()
    /// Card headlines and section titles — serif.
    static let paperHeadline = Font.system(.headline, design: .serif)
    /// Article body and prose — serif.
    static let paperBody = Font.system(.body, design: .serif)
    /// List rows and secondary prose — serif.
    static let paperCallout = Font.system(.callout, design: .serif)
    /// Metadata rows (source · time) — monospaced.
    static let paperMeta = Font.system(.caption, design: .monospaced)
    /// Badges and counters — monospaced, medium.
    static let paperBadge = Font.system(.caption2, design: .monospaced).weight(.medium)
}

// MARK: - Structural helpers

/// Hairline horizontal rule — the paper alternative to shadows and
/// rounded card borders.
struct PaperRule: View {
    var body: some View {
        Rectangle()
            .fill(Color.paperRule.opacity(0.35))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// Uppercased monospaced badge in a hairline ink box, like a printed
/// stamp. Used for category chips and counters.
struct PaperBadge: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.paperBadge)
            .foregroundStyle(Color.paperInk)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(Rectangle().stroke(Color.paperInk, lineWidth: 0.8))
    }
}

/// Primary action: ink-filled rectangle with paper-colored serif label.
/// Adaptive by construction (ink and paper swap in dark mode), unlike
/// `.borderedProminent` + tint which rendered light-on-light in dark
/// mode (issue #107).
struct PaperPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.paperHeadline)
            .foregroundStyle(Color.paperBackground)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.paperInk)
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Secondary action: hairline ink box with ink serif label, like a
/// printed coupon.
struct PaperSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.paperCallout)
            .foregroundStyle(Color.paperInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .overlay(Rectangle().stroke(Color.paperInk, lineWidth: 0.8))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == PaperPrimaryButtonStyle {
    static var paperPrimary: PaperPrimaryButtonStyle { PaperPrimaryButtonStyle() }
}

extension ButtonStyle where Self == PaperSecondaryButtonStyle {
    static var paperSecondary: PaperSecondaryButtonStyle { PaperSecondaryButtonStyle() }
}

extension View {
    /// Standard screen recipe: paper background behind everything, ink
    /// tint on controls, list chrome hidden so the paper shows through.
    func paperScreen() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.paperBackground.ignoresSafeArea())
            .tint(Color.paperInk)
    }
}

enum PaperAppearance {
    /// Serif (New York) navigation titles app-wide. Call once at launch;
    /// UIKit appearance is the only lever for large-title fonts.
    static func applyNavigationTitleFonts() {
        let large = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
            .withDesign(.serif) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
        let inline = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline)
            .withDesign(.serif) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline)
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .font: UIFont(descriptor: large, size: 0)
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .font: UIFont(descriptor: inline, size: 0)
        ]
    }
}
