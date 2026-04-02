//
//  Cluster.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation

struct Cluster: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let summary: String?
    let mainTopic: String?
    let articleIDs: [String]
    let createdAt: Date
}
