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
		"d\(sideCount) • Rolls \(rollCount)"
	}

	func statusText(lastValue: Int) -> String {
		"d\(sideCount) • Result \(lastValue)"
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

}
