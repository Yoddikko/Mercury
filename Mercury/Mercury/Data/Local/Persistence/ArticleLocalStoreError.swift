//
//  ArticleLocalStoreError.swift
//  Mercury
//
//  Created by Codex on 25/06/26.
//

import Foundation

/// Errors thrown by `ArticleLocalStore` while performing local persistence
/// operations.
enum ArticleLocalStoreError: Error, Equatable {
    /// No article matched the supplied identifier.
    case articleNotFound(id: String)
    /// The underlying SwiftData operation failed.
    case persistenceFailure(message: String)
}
