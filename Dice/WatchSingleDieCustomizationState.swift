import Foundation

struct WatchSingleDieCustomizationState: Equatable {
	private(set) var sideCount: Int
	var colorPreset: DiceDieColorPreset
	private(set) var isIntuitiveMode: Bool

	init(configuration: WatchSingleDieConfiguration) {
		sideCount = DiceSingleDieSceneGeometryFactory.clampedSideCount(configuration.sideCount)
		colorPreset = DiceDieColorPreset.fromNotation(configuration.colorTag) ?? .ivory
		isIntuitiveMode = configuration.isIntuitiveMode
	}

	mutating func setSideCount(_ sideCount: Int) {
		self.sideCount = DiceSingleDieSceneGeometryFactory.clampedSideCount(sideCount)
	}

	mutating func toggleMode() {
		isIntuitiveMode.toggle()
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
	}

	var sideToken: String {
		"d\(sideCount)"
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
}
