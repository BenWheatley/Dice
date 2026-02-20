import Foundation

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
	var soundEffectsEnabled: Bool
	var hapticsEnabled: Bool

	init(lastNotation: String, recentPresets: [String], animationsEnabled: Bool = true, animationIntensity: DiceAnimationIntensity = .full, theme: DiceTheme = .system, tableTexture: DiceTableTexture = .neutral, dieFinish: DiceDieFinish = .matte, edgeOutlinesEnabled: Bool = false, dieColorPreferences: DiceDieColorPreferences = .default, d6PipStyle: DiceD6PipStyle = .round, faceNumeralFont: DiceFaceNumeralFont = .classic, largeFaceLabelsEnabled: Bool = false, customPresets: [DiceSavedPreset] = [], motionBlurEnabled: Bool = false, boardLayoutPreset: DiceBoardLayoutPreset = .compact, soundPack: DiceSoundPack = .off, soundEffectsEnabled: Bool = true, hapticsEnabled: Bool = true) {
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
		self.soundEffectsEnabled = soundEffectsEnabled
		self.hapticsEnabled = hapticsEnabled
	}

	static var `default`: DiceUserPreferences {
		DiceUserPreferences(lastNotation: "6d6", recentPresets: [], animationsEnabled: true, animationIntensity: .full, theme: .system, tableTexture: .neutral, dieFinish: .matte, edgeOutlinesEnabled: false, dieColorPreferences: .default, d6PipStyle: .round, faceNumeralFont: .classic, largeFaceLabelsEnabled: false, customPresets: [], motionBlurEnabled: false, boardLayoutPreset: .compact, soundPack: .off, soundEffectsEnabled: true, hapticsEnabled: true)
	}
}
