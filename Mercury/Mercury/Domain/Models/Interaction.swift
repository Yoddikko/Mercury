//
//  Interaction.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation

struct Interaction: Identifiable, Equatable, Sendable {
    let id: String
    let articleID: String
    let actionType: String
    let timestamp: Date
    let readingDuration: TimeInterval?
    let scrollDepth: Double?
}
