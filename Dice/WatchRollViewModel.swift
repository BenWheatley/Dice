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
		"\(currentNotation) • \(rollCount)"
	}

	func toggleMode() {
		isIntuitiveMode.toggle()
	}

	func roll() -> RollOutcome {
		let configuration = RollConfiguration(diceCount: 1, sideCount: 6, intuitive: isIntuitiveMode)
		return rollSession.roll(configuration)
	}
}
