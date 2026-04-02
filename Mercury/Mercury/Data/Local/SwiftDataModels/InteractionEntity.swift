//
//  InteractionEntity.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation
import SwiftData

@Model
final class InteractionEntity {
    @Attribute(.unique) var id: String
    var articleID: String
    var actionType: String
    var timestamp: Date
    var readingDuration: Double?
    var scrollDepth: Double?

    init(
        id: String = UUID().uuidString.lowercased(),
        articleID: String,
        actionType: String,
        timestamp: Date = .now,
        readingDuration: Double? = nil,
        scrollDepth: Double? = nil
    ) {
        self.id = id
        self.articleID = articleID
        self.actionType = actionType
        self.timestamp = timestamp
        self.readingDuration = readingDuration
        self.scrollDepth = scrollDepth
    }
}
