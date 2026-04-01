//
//  DeveloperPlaygroundViewModel.swift
//  Mercury
//
//  Created by Codex on 01/04/26.
//

import Foundation

struct DeveloperPlaygroundViewModel {
    struct ProviderOption: Identifiable, Hashable {
        let id: String
        let displayName: String
    }

    static let defaultProviderID = "openai"

    let providerOptions: [ProviderOption] = [
        ProviderOption(id: "openai", displayName: "OpenAI"),
        ProviderOption(id: "claude", displayName: "Claude"),
        ProviderOption(id: "gemini", displayName: "Gemini"),
        ProviderOption(id: "ollama", displayName: "Ollama")
    ]

    var title: String {
        String(
            localized: "developer.playground.title",
            defaultValue: "Developer Playground"
        )
    }

    var subtitle: String {
        String(
            localized: "developer.playground.subtitle",
            defaultValue: "Debug-only sandbox to test app services and development flows."
        )
    }

    var aiSimulationSectionTitle: String {
        String(localized: "developer.playground.section.ai_simulation", defaultValue: "AI Simulation")
    }

    var providerLabel: String {
        String(localized: "developer.playground.provider", defaultValue: "Provider")
    }

    var promptInputLabel: String {
        String(localized: "developer.playground.prompt_input", defaultValue: "Prompt input")
    }

    var runSimulationLabel: String {
        String(localized: "developer.playground.run_simulation", defaultValue: "Run simulation")
    }

    var swiftDataSandboxSectionTitle: String {
        String(localized: "developer.playground.section.swiftdata_sandbox", defaultValue: "SwiftData Sandbox")
    }

    var insertSampleRecordLabel: String {
        String(localized: "developer.playground.insert_sample_record", defaultValue: "Insert sample record")
    }

    var clearRecordsLabel: String {
        String(localized: "developer.playground.clear_records", defaultValue: "Clear records")
    }

    func simulatedSummary(prompt: String, providerID: String) -> String {
        let normalizedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedPrompt.isEmpty == false else {
            return String(
                localized: "developer.playground.simulation.empty",
                defaultValue: "Enter a prompt to run a local simulation."
            )
        }

        let providerName = providerOptions.first(where: { $0.id == providerID })?.displayName ?? providerID
        let prefix = String(
            localized: "developer.playground.simulation.prefix",
            defaultValue: "Simulated summary"
        )
        let trimmedPrompt = String(normalizedPrompt.prefix(140))

        return "\(prefix) [\(providerName)]: \(trimmedPrompt)"
    }

    func makeSampleStoredArticle(existingCount: Int) -> StoredArticle {
        StoredArticle(
            title: "Debug Article \(existingCount + 1)",
            sourceName: "Developer Sandbox"
        )
    }

    func storedDebugRecordsLabel(count: Int) -> String {
        let format = String(
            localized: "developer.playground.stored_debug_records",
            defaultValue: "Stored debug records: %lld"
        )
        return String(format: format, locale: .current, Int64(count))
    }
}
