//
//  WatchSceneRenderFallbackPolicy.swift
//  Dice
//
//  Created by Codex on 11.03.26.
//

import Foundation

enum WatchSceneFallbackReason: Equatable {
	case sceneViewUnavailable
	case unsupportedSideCount
	case sharedGeometryUnavailable(isHighCost: Bool)
}

enum WatchSceneRenderDecision: Equatable {
	case sceneKit(sideCount: Int)
	case staticImage(sideCount: Int, reason: WatchSceneFallbackReason)

	var sideCount: Int {
		switch self {
		case let .sceneKit(sideCount):
			return sideCount
		case let .staticImage(sideCount, _):
			return sideCount
		}
	}
}

enum WatchSceneRenderFallbackPolicy {
	static func resolve(
		rawSideCount: Int,
		isSceneViewReady: Bool,
		canBuildSharedGeometry: (Int) -> Bool = defaultCanBuildSharedGeometry
	) -> WatchSceneRenderDecision {
		let clampedSideCount = DiceSingleDieSceneGeometryFactory.clampedSideCount(rawSideCount)
		guard isSceneViewReady else {
			return .staticImage(sideCount: clampedSideCount, reason: .sceneViewUnavailable)
		}
		let isInSupportedRange = (DiceSingleDieSceneGeometryFactory.minimumSideCount...DiceSingleDieSceneGeometryFactory.maximumSideCount).contains(rawSideCount)
		guard isInSupportedRange else {
			return .staticImage(sideCount: clampedSideCount, reason: .unsupportedSideCount)
		}
		guard canBuildSharedGeometry(clampedSideCount) else {
			// Keep SceneKit as the first-class watch path for all supported sides.
			// Static image mode is only a resilience fallback when shared SceneKit geometry cannot be built.
			return .staticImage(
				sideCount: clampedSideCount,
				reason: .sharedGeometryUnavailable(isHighCost: isHighCostGeometry(sideCount: clampedSideCount))
			)
		}
		return .sceneKit(sideCount: clampedSideCount)
	}

	static func isHighCostGeometry(sideCount: Int) -> Bool {
		DiceSingleDieSceneGeometryFactory.usesTokenGeometry(for: sideCount)
	}

	private static func defaultCanBuildSharedGeometry(sideCount: Int) -> Bool {
		_ = DiceSingleDieSceneGeometryFactory.makeDescriptor(sideCount: sideCount, sideLength: 1.8)
		return true
	}
}
