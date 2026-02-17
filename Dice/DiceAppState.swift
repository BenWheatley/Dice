//
//  DiceAppState.swift
//  Dice
//
//  Created by Codex on 16.02.26.
//

import Foundation

struct DiceStats {
	var localTotals: [Int]
	var sessionTotals: [Int]
	var totalRolls: Int
	var sum: Int

	static var empty: DiceStats {
		DiceStats(localTotals: [], sessionTotals: [], totalRolls: 0, sum: 0)
	}

	init(localTotals: [Int], sessionTotals: [Int], totalRolls: Int, sum: Int) {
		self.localTotals = localTotals
		self.sessionTotals = sessionTotals
		self.totalRolls = totalRolls
		self.sum = sum
	}

	init(outcome: RollOutcome) {
		self.init(
			localTotals: outcome.localTotals,
			sessionTotals: outcome.sessionTotals,
			totalRolls: outcome.totalRolls,
			sum: outcome.sum
		)
	}
}

final class DiceAppState {
	var configuration: RollConfiguration
	var diceValues: [Int]
	var diceSideCounts: [Int]
	var stats: DiceStats
	var animationsEnabled: Bool
	var animationIntensity: DiceAnimationIntensity
	var theme: DiceTheme
	var tableTexture: DiceTableTexture
	var dieFinish: DiceDieFinish
	var edgeOutlinesEnabled: Bool
	var dieColorPreferences: DiceDieColorPreferences
	var d6PipStyle: DiceD6PipStyle
	var faceNumeralFont: DiceFaceNumeralFont
	var lastRolledConfiguration: RollConfiguration?
	var lockedDieIndices: Set<Int>
	var boardCameraPreset: DiceBoardCameraPreset

	init(configuration: RollConfiguration = RollConfiguration(diceCount: 6, sideCount: 6, intuitive: false)) {
		self.configuration = configuration
		self.diceValues = Array(repeating: 1, count: configuration.diceCount)
		self.diceSideCounts = configuration.sideCountsPerDie
		self.stats = .empty
		self.animationsEnabled = true
		self.animationIntensity = .full
		self.theme = .classic
		self.tableTexture = .neutral
		self.dieFinish = .matte
		self.edgeOutlinesEnabled = false
		self.dieColorPreferences = .default
		self.d6PipStyle = .round
		self.faceNumeralFont = .classic
		self.lastRolledConfiguration = nil
		self.lockedDieIndices = []
		self.boardCameraPreset = .slightTilt
	}

	func applyRollOutcome(_ outcome: RollOutcome) {
		diceValues = outcome.values
		diceSideCounts = outcome.sideCounts
		stats = DiceStats(outcome: outcome)
		lockedDieIndices = lockedDieIndices.filter { $0 >= 0 && $0 < diceValues.count }
	}
}
