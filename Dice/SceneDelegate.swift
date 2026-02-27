//
//  SceneDelegate.swift
//  Dice
//
//  Created by Codex on 16.02.26.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
	var window: UIWindow?

	func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
		if let route = connectionOptions.urlContexts.compactMap({ DiceAppRoute(url: $0.url) }).first {
			post(route: route)
		}
	}

	func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
		guard let route = URLContexts.compactMap({ DiceAppRoute(url: $0.url) }).first else { return }
		post(route: route)
	}

	private func post(route: DiceAppRoute) {
		NotificationCenter.default.post(name: .diceRouteRequested, object: route)
	}
}
