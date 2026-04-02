//
//  AIProviderCredentialStore.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation
import Security

protocol AIProviderCredentialStore: Sendable {
    nonisolated func loadToken(for providerID: AIProviderID) throws -> String?
    nonisolated func saveToken(_ token: String?, for providerID: AIProviderID) throws
    nonisolated func deleteToken(for providerID: AIProviderID) throws
}

enum AIProviderCredentialStoreError: Error, Sendable, Equatable, LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidTokenEncoding

    var errorDescription: String? {
        switch self {
        case let .unexpectedStatus(status):
            return "Keychain operation failed with status \(status)."
        case .invalidTokenEncoding:
            return "Token could not be decoded from Keychain."
        }
    }
}

struct KeychainAIProviderCredentialStore: AIProviderCredentialStore, @unchecked Sendable {
    private let service: String

    nonisolated init(service: String = "com.mercury.ai.provider.tokens") {
        self.service = service
    }

    nonisolated func loadToken(for providerID: AIProviderID) throws -> String? {
        var query = baseQuery(for: providerID)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw AIProviderCredentialStoreError.unexpectedStatus(status)
        }

        guard let data = result as? Data, let token = String(data: data, encoding: .utf8) else {
            throw AIProviderCredentialStoreError.invalidTokenEncoding
        }

        return token
    }

    nonisolated func saveToken(_ token: String?, for providerID: AIProviderID) throws {
        let trimmed = token?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            try deleteToken(for: providerID)
            return
        }

        let data = Data(trimmed.utf8)
        try upsertTokenData(data, for: providerID)
    }

    nonisolated func deleteToken(for providerID: AIProviderID) throws {
        let status = SecItemDelete(baseQuery(for: providerID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AIProviderCredentialStoreError.unexpectedStatus(status)
        }
    }

    nonisolated private func upsertTokenData(_ data: Data, for providerID: AIProviderID) throws {
        var query = baseQuery(for: providerID)
        query[kSecValueData as String] = data

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return
        }

        guard addStatus == errSecDuplicateItem else {
            throw AIProviderCredentialStoreError.unexpectedStatus(addStatus)
        }

        let updateStatus = SecItemUpdate(
            baseQuery(for: providerID) as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        guard updateStatus == errSecSuccess else {
            throw AIProviderCredentialStoreError.unexpectedStatus(updateStatus)
        }
    }

    nonisolated private func baseQuery(for providerID: AIProviderID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerID.rawValue
        ]
    }
}
