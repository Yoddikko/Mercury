//
//  DeveloperMode.swift
//  Mercury
//
//  Created by Codex on 01/04/26.
//

import Foundation

enum DeveloperMode {
    private static let launchArgument = "-developer-mode"

    static var isEnabled: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains(launchArgument)
#else
        false
#endif
    }
}
