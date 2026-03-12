//
//  WatchAccessibilityFormatter.swift
//  Dice
//
//  Created by Codex on 12.03.26.
//

import Foundation

enum WatchAccessibilityFormatter {
	static let rollButtonLabel = "Roll dice"
	static let rollButtonHint = "Double tap to roll one die"
	static let latestResultLabel = "Latest die result"
	static let scenePreviewLabel = "Latest die result, 3D preview"

	static func dieValue(value: Int, sideCount: Int) -> String {
		let safeValue = max(1, value)
		let safeSideCount = max(1, sideCount)
		return "Value \(safeValue) on d\(safeSideCount)"
	}
}
