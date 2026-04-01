//
//  StoredArticle.swift
//  Mercury
//
//  Created by Codex on 01/04/26.
//

import Foundation
import SwiftData

@Model
final class StoredArticle {
    @Attribute(.unique) var id: UUID
    var title: String
    var sourceName: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        sourceName: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.sourceName = sourceName
        self.createdAt = createdAt
    }
}
