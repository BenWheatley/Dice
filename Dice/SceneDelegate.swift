//
//  SceneDelegate.swift
//  Dice
//
//  Created by Codex on 16.02.26.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
	var window: UIWindow?
	private var pendingRoute: DiceAppRoute?
	private let snapshotStore = DiceWidgetSnapshotStore()

	func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
		pendingRoute = initialRoute(from: connectionOptions)
		if let window,
		   let root = window.rootViewController,
		   !(root is UINavigationController) {
			let navigationController = UINavigationController(rootViewController: root)
			window.rootViewController = navigationController
		}
	}

	func sceneDidBecomeActive(_ scene: UIScene) {
		guard let route = pendingRoute else { return }
		pendingRoute = nil
		post(route: route, scene: scene)
	}

	func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
		guard let route = URLContexts.compactMap({ DiceAppRoute(url: $0.url) }).first else { return }
		post(route: route, scene: scene)
	}

	func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
		let snapshot = snapshotStore.loadSnapshot()
		guard let route = DiceQuickActionRouter.route(for: shortcutItem.type, snapshot: snapshot) else {
			completionHandler(false)
			return
		}
		post(route: route, scene: windowScene)
		completionHandler(true)
	}

	private func initialRoute(from options: UIScene.ConnectionOptions) -> DiceAppRoute? {
		if let route = options.urlContexts.compactMap({ DiceAppRoute(url: $0.url) }).first {
			return route
		}
		if let shortcutItem = options.shortcutItem {
			let snapshot = snapshotStore.loadSnapshot()
			return DiceQuickActionRouter.route(for: shortcutItem.type, snapshot: snapshot)
		}
		return nil
	}

	private func post(route: DiceAppRoute, scene: UIScene) {
		NotificationCenter.default.post(
			name: .diceRouteRequested,
			object: scene,
			userInfo: [DiceRouteNotificationKey.route: route]
		)
	}
}
