//
//  DiceAppState.swift
//  Dice
//
//  Created by Codex on 16.02.26.
//

import Foundation

final class DiceAppState {
	var configuration: RollConfiguration
	var diceValues: [Int]
	var diceSideCounts: [Int]
	var stats: DiceStats
	var animationsEnabled: Bool
	var animationIntensity: DiceAnimationIntensity
	var theme: DiceTheme
	var lightingAngle: DiceLightingAngle
	var tableTexture: DiceTableTexture
	var dieFinish: DiceDieFinish
	var edgeOutlinesEnabled: Bool
	var dieColorPreferences: DiceDieColorPreferences
	var d6PipStyle: DiceD6PipStyle
	var faceNumeralFont: DiceFaceNumeralFont
	var dieFaceNumeralFontOverrides: [Int: DiceFaceNumeralFont]
	var dieColorOverrides: [Int: DiceDieColorPreset]
	var largeFaceLabelsEnabled: Bool
	var lastRolledConfiguration: RollConfiguration?
	var lockedDieIndices: Set<Int>
	var motionBlurEnabled: Bool
	var boardLayoutPreset: DiceBoardLayoutPreset
	var soundPack: DiceSoundPack
	var soundEffectsEnabled: Bool
	var hapticsEnabled: Bool

	init(configuration: RollConfiguration = RollConfiguration(diceCount: 6, sideCount: 6, intuitive: false)) {
		self.configuration = configuration
		self.diceValues = Array(repeating: 1, count: configuration.diceCount)
		self.diceSideCounts = configuration.sideCountsPerDie
		self.stats = .empty
		self.animationsEnabled = true
		self.animationIntensity = .full
		self.theme = .system
		self.lightingAngle = .natural
		self.tableTexture = .neutral
		self.dieFinish = .matte
		self.edgeOutlinesEnabled = false
		self.dieColorPreferences = .default
		self.d6PipStyle = .round
		self.faceNumeralFont = .classic
		self.dieFaceNumeralFontOverrides = [:]
		self.dieColorOverrides = [:]
		self.largeFaceLabelsEnabled = false
		self.lastRolledConfiguration = nil
		self.lockedDieIndices = []
		self.motionBlurEnabled = false
		self.boardLayoutPreset = .compact
		self.soundPack = .off
		self.soundEffectsEnabled = true
		self.hapticsEnabled = true
	}

	func applyRollOutcome(_ outcome: RollOutcome) {
		diceValues = outcome.values
		diceSideCounts = outcome.sideCounts
		stats = DiceStats(outcome: outcome)
		lockedDieIndices = lockedDieIndices.filter { $0 >= 0 && $0 < diceValues.count }
		dieFaceNumeralFontOverrides = dieFaceNumeralFontOverrides.filter { $0.key >= 0 && $0.key < diceValues.count }
		dieColorOverrides = dieColorOverrides.filter { $0.key >= 0 && $0.key < diceValues.count }
	}
}
