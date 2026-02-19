//
//  DicePreferencesStore.swift
//  Dice
//
//  Created by Codex on 16.02.26.
//

import Foundation
import UIKit

struct DiceSavedPreset: Codable, Equatable, Identifiable {
	let id: String
	var title: String
	var notation: String
	var pinned: Bool

	init(id: String = UUID().uuidString, title: String, notation: String, pinned: Bool = false) {
		self.id = id
		self.title = title
		self.notation = notation
		self.pinned = pinned
	}
}

struct DiceUserPreferences: Equatable {
	var lastNotation: String
	var recentPresets: [String]
	var animationsEnabled: Bool
	var animationIntensity: DiceAnimationIntensity
	var theme: DiceTheme
	var tableTexture: DiceTableTexture
	var dieFinish: DiceDieFinish
	var edgeOutlinesEnabled: Bool
	var dieColorPreferences: DiceDieColorPreferences
	var d6PipStyle: DiceD6PipStyle
	var faceNumeralFont: DiceFaceNumeralFont
	var largeFaceLabelsEnabled: Bool
	var customPresets: [DiceSavedPreset]
	var motionBlurEnabled: Bool
	var boardLayoutPreset: DiceBoardLayoutPreset
	var soundPack: DiceSoundPack
	var soundVolume: Float
	var soundEffectsEnabled: Bool
	var hapticsEnabled: Bool

	init(lastNotation: String, recentPresets: [String], animationsEnabled: Bool = true, animationIntensity: DiceAnimationIntensity = .full, theme: DiceTheme = .system, tableTexture: DiceTableTexture = .neutral, dieFinish: DiceDieFinish = .matte, edgeOutlinesEnabled: Bool = false, dieColorPreferences: DiceDieColorPreferences = .default, d6PipStyle: DiceD6PipStyle = .round, faceNumeralFont: DiceFaceNumeralFont = .classic, largeFaceLabelsEnabled: Bool = false, customPresets: [DiceSavedPreset] = [], motionBlurEnabled: Bool = false, boardLayoutPreset: DiceBoardLayoutPreset = .compact, soundPack: DiceSoundPack = .off, soundVolume: Float = 0.65, soundEffectsEnabled: Bool = true, hapticsEnabled: Bool = true) {
		self.lastNotation = lastNotation
		self.recentPresets = recentPresets
		self.animationsEnabled = animationsEnabled
		self.animationIntensity = animationIntensity
		self.theme = theme
		self.tableTexture = tableTexture
		self.dieFinish = dieFinish
		self.edgeOutlinesEnabled = edgeOutlinesEnabled
		self.dieColorPreferences = dieColorPreferences
		self.d6PipStyle = d6PipStyle
		self.faceNumeralFont = faceNumeralFont
		self.largeFaceLabelsEnabled = largeFaceLabelsEnabled
		self.customPresets = customPresets
		self.motionBlurEnabled = motionBlurEnabled
		self.boardLayoutPreset = boardLayoutPreset
		self.soundPack = soundPack
		self.soundVolume = soundVolume
		self.soundEffectsEnabled = soundEffectsEnabled
		self.hapticsEnabled = hapticsEnabled
	}

	static var `default`: DiceUserPreferences {
		DiceUserPreferences(lastNotation: "6d6", recentPresets: [], animationsEnabled: true, animationIntensity: .full, theme: .system, tableTexture: .neutral, dieFinish: .matte, edgeOutlinesEnabled: false, dieColorPreferences: .default, d6PipStyle: .round, faceNumeralFont: .classic, largeFaceLabelsEnabled: false, customPresets: [], motionBlurEnabled: false, boardLayoutPreset: .compact, soundPack: .off, soundVolume: 0.65, soundEffectsEnabled: true, hapticsEnabled: true)
	}
}

final class DicePreferencesStore {
	private enum Keys {
		static let lastNotation = "Dice.lastNotation"
		static let recentPresets = "Dice.recentPresets"
		static let animationsEnabled = "Dice.animationsEnabled"
		static let animationIntensity = "Dice.animationIntensity"
		static let theme = "Dice.theme"
		static let tableTexture = "Dice.tableTexture"
		static let dieFinish = "Dice.dieFinish"
		static let edgeOutlinesEnabled = "Dice.edgeOutlinesEnabled"
		static let dieColors = "Dice.dieColors"
		static let d6PipStyle = "Dice.d6PipStyle"
		static let faceNumeralFont = "Dice.faceNumeralFont"
		static let largeFaceLabelsEnabled = "Dice.largeFaceLabelsEnabled"
		static let customPresets = "Dice.customPresets"
		static let motionBlurEnabled = "Dice.motionBlurEnabled"
		static let boardLayoutPreset = "Dice.boardLayoutPreset"
		static let soundPack = "Dice.soundPack"
		static let soundVolume = "Dice.soundVolume"
		static let soundEffectsEnabled = "Dice.soundEffectsEnabled"
		static let hapticsEnabled = "Dice.hapticsEnabled"
	}

	private let defaults: UserDefaults
	private let maxRecentPresets: Int
	private let voiceOverIsRunning: () -> Bool

	init(defaults: UserDefaults = .standard, maxRecentPresets: Int = 12, voiceOverIsRunning: @escaping () -> Bool = { UIAccessibility.isVoiceOverRunning }) {
		self.defaults = defaults
		self.maxRecentPresets = maxRecentPresets
		self.voiceOverIsRunning = voiceOverIsRunning
	}

	func load() -> DiceUserPreferences {
		let notation = defaults.string(forKey: Keys.lastNotation) ?? DiceUserPreferences.default.lastNotation
		let presets = defaults.array(forKey: Keys.recentPresets) as? [String] ?? []
		let animationsEnabled = defaults.object(forKey: Keys.animationsEnabled) as? Bool ?? DiceUserPreferences.default.animationsEnabled
		let rawAnimationIntensity = defaults.string(forKey: Keys.animationIntensity)
		let animationIntensity = mappedAnimationIntensity(rawAnimationIntensity)
			?? (animationsEnabled ? .full : .off)
		let rawTheme = defaults.string(forKey: Keys.theme)
		let theme = mappedTheme(rawTheme) ?? DiceUserPreferences.default.theme
		let rawTexture = defaults.string(forKey: Keys.tableTexture)
		let tableTexture = rawTexture.flatMap(DiceTableTexture.init(rawValue:)) ?? DiceUserPreferences.default.tableTexture
		let rawFinish = defaults.string(forKey: Keys.dieFinish)
		let dieFinish = rawFinish.flatMap(DiceDieFinish.init(rawValue:)) ?? DiceUserPreferences.default.dieFinish
		let edgeOutlinesEnabled = defaults.object(forKey: Keys.edgeOutlinesEnabled) as? Bool ?? DiceUserPreferences.default.edgeOutlinesEnabled
		let rawDieColors = defaults.dictionary(forKey: Keys.dieColors) as? [String: String] ?? [:]
		let dieColorPreferences = DiceDieColorPreferences.deserialize(rawDieColors)
		let rawPipStyle = defaults.string(forKey: Keys.d6PipStyle)
		let d6PipStyle = rawPipStyle.flatMap(DiceD6PipStyle.init(rawValue:)) ?? DiceUserPreferences.default.d6PipStyle
		let rawFaceNumeralFont = defaults.string(forKey: Keys.faceNumeralFont)
		let faceNumeralFont = rawFaceNumeralFont.flatMap(DiceFaceNumeralFont.init(rawValue:)) ?? DiceUserPreferences.default.faceNumeralFont
		let largeFaceLabelsEnabled = defaults.object(forKey: Keys.largeFaceLabelsEnabled) as? Bool ?? DiceUserPreferences.default.largeFaceLabelsEnabled
		let customPresets = decodeCustomPresets(from: defaults.data(forKey: Keys.customPresets))
		let motionBlurEnabled = defaults.object(forKey: Keys.motionBlurEnabled) as? Bool ?? DiceUserPreferences.default.motionBlurEnabled
		let rawLayoutPreset = defaults.string(forKey: Keys.boardLayoutPreset)
		let boardLayoutPreset = mappedLayoutPreset(rawLayoutPreset) ?? DiceUserPreferences.default.boardLayoutPreset
		let rawSoundPack = defaults.string(forKey: Keys.soundPack)
		let soundPack = rawSoundPack.flatMap(DiceSoundPack.init(rawValue:)) ?? DiceUserPreferences.default.soundPack
		let soundVolume = defaults.object(forKey: Keys.soundVolume) as? Float ?? DiceUserPreferences.default.soundVolume
		let soundEffectsEnabled: Bool
		if let storedSfxEnabled = defaults.object(forKey: Keys.soundEffectsEnabled) as? Bool {
			soundEffectsEnabled = storedSfxEnabled
		} else {
			soundEffectsEnabled = voiceOverIsRunning() ? false : DiceUserPreferences.default.soundEffectsEnabled
		}
		let hapticsEnabled = defaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? DiceUserPreferences.default.hapticsEnabled
		return DiceUserPreferences(
			lastNotation: notation,
			recentPresets: presets,
			animationsEnabled: animationsEnabled,
			animationIntensity: animationIntensity,
			theme: theme,
			tableTexture: tableTexture,
			dieFinish: dieFinish,
			edgeOutlinesEnabled: edgeOutlinesEnabled,
			dieColorPreferences: dieColorPreferences,
			d6PipStyle: d6PipStyle,
			faceNumeralFont: faceNumeralFont,
			largeFaceLabelsEnabled: largeFaceLabelsEnabled,
			customPresets: customPresets,
			motionBlurEnabled: motionBlurEnabled,
			boardLayoutPreset: boardLayoutPreset,
			soundPack: soundPack,
			soundVolume: min(max(soundVolume, 0), 1),
			soundEffectsEnabled: soundEffectsEnabled,
			hapticsEnabled: hapticsEnabled
		)
	}

	func save(_ preferences: DiceUserPreferences) {
		defaults.set(preferences.lastNotation, forKey: Keys.lastNotation)
		defaults.set(Array(preferences.recentPresets.prefix(maxRecentPresets)), forKey: Keys.recentPresets)
		defaults.set(preferences.animationsEnabled, forKey: Keys.animationsEnabled)
		defaults.set(preferences.animationIntensity.rawValue, forKey: Keys.animationIntensity)
		defaults.set(preferences.theme.rawValue, forKey: Keys.theme)
		defaults.set(preferences.tableTexture.rawValue, forKey: Keys.tableTexture)
		defaults.set(preferences.dieFinish.rawValue, forKey: Keys.dieFinish)
		defaults.set(preferences.edgeOutlinesEnabled, forKey: Keys.edgeOutlinesEnabled)
		defaults.set(preferences.dieColorPreferences.serialized(), forKey: Keys.dieColors)
		defaults.set(preferences.d6PipStyle.rawValue, forKey: Keys.d6PipStyle)
		defaults.set(preferences.faceNumeralFont.rawValue, forKey: Keys.faceNumeralFont)
		defaults.set(preferences.largeFaceLabelsEnabled, forKey: Keys.largeFaceLabelsEnabled)
		defaults.set(encodeCustomPresets(preferences.customPresets), forKey: Keys.customPresets)
		defaults.set(preferences.motionBlurEnabled, forKey: Keys.motionBlurEnabled)
		defaults.set(preferences.boardLayoutPreset.rawValue, forKey: Keys.boardLayoutPreset)
		defaults.set(preferences.soundPack.rawValue, forKey: Keys.soundPack)
		defaults.set(min(max(preferences.soundVolume, 0), 1), forKey: Keys.soundVolume)
		defaults.set(preferences.soundEffectsEnabled, forKey: Keys.soundEffectsEnabled)
		defaults.set(preferences.hapticsEnabled, forKey: Keys.hapticsEnabled)
	}

	func addRecentPreset(_ notation: String) {
		var preferences = load()
		preferences.recentPresets.removeAll { $0 == notation }
		preferences.recentPresets.insert(notation, at: 0)
		save(preferences)
	}

	private func decodeCustomPresets(from data: Data?) -> [DiceSavedPreset] {
		guard let data else { return [] }
		guard let decoded = try? JSONDecoder().decode([DiceSavedPreset].self, from: data) else { return [] }
		return decoded
	}

	private func encodeCustomPresets(_ presets: [DiceSavedPreset]) -> Data? {
		try? JSONEncoder().encode(presets)
	}

	private func mappedAnimationIntensity(_ rawValue: String?) -> DiceAnimationIntensity? {
		guard let rawValue else { return nil }
		if rawValue == "subtle" {
			return .full
		}
		return DiceAnimationIntensity(rawValue: rawValue)
	}

	private func mappedTheme(_ rawValue: String?) -> DiceTheme? {
		guard let rawValue else { return nil }
		switch rawValue {
		case "classic":
			return .lightMode
		case "darkSlate":
			return .darkMode
		case "highContrast":
			return .system
		default:
			return DiceTheme(rawValue: rawValue)
		}
	}

	private func mappedLayoutPreset(_ rawValue: String?) -> DiceBoardLayoutPreset? {
		guard let rawValue else { return nil }
		if rawValue == "balanced" {
			return .compact
		}
		return DiceBoardLayoutPreset(rawValue: rawValue)
	}
}
