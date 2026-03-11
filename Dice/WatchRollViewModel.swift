//
//  WatchRollViewModel.swift
//  Dice
//
//  Created by Codex on 16.02.26.
//

import Foundation

final class WatchRollViewModel {
	private let rollSession: DiceRollSession
	private(set) var isIntuitiveMode: Bool
	private(set) var sideCount: Int
	private var lastRollConfiguration: RollConfiguration?

	init(
		rollSession: DiceRollSession = DiceRollSession(),
		isIntuitiveMode: Bool = false,
		sideCount: Int = 6
	) {
		self.rollSession = rollSession
		self.isIntuitiveMode = isIntuitiveMode
		self.sideCount = DiceSingleDieSceneGeometryFactory.clampedSideCount(sideCount)
	}

	var currentNotation: String {
		let base = "1d\(sideCount)"
		return isIntuitiveMode ? "\(base)i" : base
	}

	func statusText(rollCount: Int) -> String {
		"\(compactModeToken())·\(compactNotationToken())\nr\(rollCount)"
	}

	func statusText(lastValue: Int) -> String {
		"\(compactModeToken())·\(compactNotationToken())\nv\(lastValue)"
	}

	func toggleMode() {
		isIntuitiveMode.toggle()
	}

	func setIntuitiveMode(_ enabled: Bool) {
		isIntuitiveMode = enabled
	}

	func setSideCount(_ sideCount: Int) {
		self.sideCount = DiceSingleDieSceneGeometryFactory.clampedSideCount(sideCount)
		lastRollConfiguration = nil
	}

	func roll() -> RollOutcome {
		let configuration = RollConfiguration(diceCount: 1, sideCount: sideCount, intuitive: isIntuitiveMode)
		lastRollConfiguration = configuration
		return rollSession.roll(configuration)
	}

	func repeatLastRoll() -> RollOutcome {
		let configuration = lastRollConfiguration ?? RollConfiguration(diceCount: 1, sideCount: sideCount, intuitive: isIntuitiveMode)
		lastRollConfiguration = configuration
		return rollSession.roll(configuration)
	}

	private func compactModeToken() -> String {
		isIntuitiveMode ? "INT" : "TR"
	}

	private func compactNotationToken(maxLength: Int = 6) -> String {
		let token = currentNotation.replacingOccurrences(of: " ", with: "")
		guard token.count > maxLength else { return token }
		return String(token.prefix(maxLength - 1)) + "…"
	}
}
