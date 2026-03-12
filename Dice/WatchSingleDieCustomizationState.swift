import Foundation

struct WatchSingleDieCustomizationState: Equatable {
	static let quickChipSideCounts = [2, 4, 6, 8, 10, 12, 20]
	static let pickerSideCounts = Array(
		DiceSingleDieSceneGeometryFactory.minimumSideCount...DiceSingleDieSceneGeometryFactory.maximumSideCount
	)

	private(set) var sideCount: Int
	var colorPreset: DiceDieColorPreset
	private(set) var isIntuitiveMode: Bool
	private(set) var backgroundTexture: DiceTableTexture

	init(configuration: WatchSingleDieConfiguration) {
		sideCount = DiceSingleDieSceneGeometryFactory.clampedSideCount(configuration.sideCount)
		colorPreset = DiceDieColorPreset.fromNotation(configuration.colorTag) ?? .ivory
		isIntuitiveMode = configuration.isIntuitiveMode
		backgroundTexture = DiceTableTexture(rawValue: configuration.backgroundTexture) ?? .black
	}

	mutating func setSideCount(_ sideCount: Int) {
		self.sideCount = DiceSingleDieSceneGeometryFactory.clampedSideCount(sideCount)
	}

	mutating func setSideCountFromPickerIndex(_ index: Int) {
		let maxIndex = Self.pickerSideCounts.count - 1
		let clampedIndex = min(max(0, index), maxIndex)
		sideCount = Self.pickerSideCounts[clampedIndex]
	}

	func isQuickChipSelected(_ quickChipSideCount: Int) -> Bool {
		sideCount == quickChipSideCount
	}

	static func pickerIndex(forSideCount sideCount: Int) -> Int {
		let clamped = DiceSingleDieSceneGeometryFactory.clampedSideCount(sideCount)
		return clamped - DiceSingleDieSceneGeometryFactory.minimumSideCount
	}

	mutating func toggleMode() {
		isIntuitiveMode.toggle()
	}

	mutating func cycleBackgroundForward() {
		let allTextures = DiceTableTexture.allCases
		guard let index = allTextures.firstIndex(of: backgroundTexture) else {
			backgroundTexture = .black
			return
		}
		let next = (index + 1) % allTextures.count
		backgroundTexture = allTextures[next]
	}

	mutating func cycleColorForward() {
		let colors = DiceDieColorPreset.allCases
		guard let index = colors.firstIndex(of: colorPreset) else {
			colorPreset = .ivory
			return
		}
		let next = (index + 1) % colors.count
		colorPreset = colors[next]
	}

	func apply(to configuration: inout WatchSingleDieConfiguration) {
		configuration.sideCount = sideCount
		configuration.colorTag = colorPreset.notationName
		configuration.isIntuitiveMode = isIntuitiveMode
		configuration.backgroundTexture = backgroundTexture.rawValue
	}

	var sideToken: String {
		"d\(sideCount)"
	}

	var sidePickerIndex: Int {
		Self.pickerIndex(forSideCount: sideCount)
	}

	var modeToken: String {
		isIntuitiveMode ? "INT" : "TR"
	}

	var colorToken: String {
		switch colorPreset {
		case .ivory:
			return "Ivory"
		case .crimson:
			return "Crimson"
		case .emerald:
			return "Emerald"
		case .sapphire:
			return "Sapphire"
		case .amber:
			return "Amber"
		case .slate:
			return "Slate"
		}
	}

	var backgroundToken: String {
		switch backgroundTexture {
		case .black:
			return "Black"
		case .felt:
			return "Felt"
		case .wood:
			return "Wood"
		case .neutral:
			return "Neutral"
		}
	}
}
