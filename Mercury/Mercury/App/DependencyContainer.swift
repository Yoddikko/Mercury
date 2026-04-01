//
//  DependencyContainer.swift
//  Mercury
//
//  Created by Codex on 31/03/26.
//

struct DependencyContainer {
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel()
    }

#if DEBUG
    func makeDeveloperPlaygroundViewModel() -> DeveloperPlaygroundViewModel {
        DeveloperPlaygroundViewModel()
    }
#endif
}
