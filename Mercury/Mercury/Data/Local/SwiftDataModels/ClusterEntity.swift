//
//  ClusterEntity.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation
import SwiftData

@Model
final class ClusterEntity {
    @Attribute(.unique) var id: String
    var title: String
    var summary: String?
    var mainTopic: String?
    var articleIDs: [String]
    var createdAt: Date

    init(
        id: String = UUID().uuidString.lowercased(),
        title: String,
        summary: String? = nil,
        mainTopic: String? = nil,
        articleIDs: [String] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.mainTopic = mainTopic
        self.articleIDs = articleIDs
        self.createdAt = createdAt
    }
}
