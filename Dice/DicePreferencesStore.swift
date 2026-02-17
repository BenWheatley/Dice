//
//  DicePreferencesStore.swift
//  Dice
//
//  Created by Codex on 16.02.26.
//

import Foundation

struct DiceUserPreferences: Equatable {
	var lastNotation: String
	var recentPresets: [String]
	var animationsEnabled: Bool
	var theme: DiceTheme

	init(lastNotation: String, recentPresets: [String], animationsEnabled: Bool = true, theme: DiceTheme = .classic) {
		self.lastNotation = lastNotation
		self.recentPresets = recentPresets
		self.animationsEnabled = animationsEnabled
		self.theme = theme
	}

	static var `default`: DiceUserPreferences {
		DiceUserPreferences(lastNotation: "6d6", recentPresets: [], animationsEnabled: true, theme: .classic)
	}
}

final class DicePreferencesStore {
	private enum Keys {
		static let lastNotation = "Dice.lastNotation"
		static let recentPresets = "Dice.recentPresets"
		static let animationsEnabled = "Dice.animationsEnabled"
		static let theme = "Dice.theme"
	}

	private let defaults: UserDefaults
	private let maxRecentPresets: Int

	init(defaults: UserDefaults = .standard, maxRecentPresets: Int = 12) {
		self.defaults = defaults
		self.maxRecentPresets = maxRecentPresets
	}

	func load() -> DiceUserPreferences {
		let notation = defaults.string(forKey: Keys.lastNotation) ?? DiceUserPreferences.default.lastNotation
		let presets = defaults.array(forKey: Keys.recentPresets) as? [String] ?? []
		let animationsEnabled = defaults.object(forKey: Keys.animationsEnabled) as? Bool ?? DiceUserPreferences.default.animationsEnabled
		let rawTheme = defaults.string(forKey: Keys.theme)
		let theme = rawTheme.flatMap(DiceTheme.init(rawValue:)) ?? DiceUserPreferences.default.theme
		return DiceUserPreferences(lastNotation: notation, recentPresets: presets, animationsEnabled: animationsEnabled, theme: theme)
	}

	func save(_ preferences: DiceUserPreferences) {
		defaults.set(preferences.lastNotation, forKey: Keys.lastNotation)
		defaults.set(Array(preferences.recentPresets.prefix(maxRecentPresets)), forKey: Keys.recentPresets)
		defaults.set(preferences.animationsEnabled, forKey: Keys.animationsEnabled)
		defaults.set(preferences.theme.rawValue, forKey: Keys.theme)
	}

	func addRecentPreset(_ notation: String) {
		var preferences = load()
		preferences.recentPresets.removeAll { $0 == notation }
		preferences.recentPresets.insert(notation, at: 0)
		save(preferences)
	}
}
