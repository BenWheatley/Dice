import Foundation

struct DiceStylePreviewState {
	let theme: DiceTheme
	let texture: DiceTableTexture
	let dieFinish: DiceDieFinish
	let edgeOutlinesEnabled: Bool
	let dieColors: DiceDieColorPreferences
	let d6PipStyle: DiceD6PipStyle
	let faceNumeralFont: DiceFaceNumeralFont
	let largeFaceLabelsEnabled: Bool
}
