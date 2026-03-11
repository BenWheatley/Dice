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
	private var lastRollConfiguration: RollConfiguration?

	init(
		rollSession: DiceRollSession = DiceRollSession(),
		isIntuitiveMode: Bool = false
	) {
		self.rollSession = rollSession
		self.isIntuitiveMode = isIntuitiveMode
	}

	var currentNotation: String {
		isIntuitiveMode ? "1d6i" : "1d6"
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

	func roll() -> RollOutcome {
		let configuration = RollConfiguration(diceCount: 1, sideCount: 6, intuitive: isIntuitiveMode)
		lastRollConfiguration = configuration
		return rollSession.roll(configuration)
	}

	func repeatLastRoll() -> RollOutcome {
		let configuration = lastRollConfiguration ?? RollConfiguration(diceCount: 1, sideCount: 6, intuitive: isIntuitiveMode)
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
