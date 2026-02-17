import UIKit

enum DiceDieColorPreset: String, CaseIterable {
	case ivory
	case crimson
	case emerald
	case sapphire
	case amber
	case slate

	var menuTitleKey: String {
		switch self {
		case .ivory:
			return "dieColor.ivory"
		case .crimson:
			return "dieColor.crimson"
		case .emerald:
			return "dieColor.emerald"
		case .sapphire:
			return "dieColor.sapphire"
		case .amber:
			return "dieColor.amber"
		case .slate:
			return "dieColor.slate"
		}
	}

	var fillColor: UIColor {
		switch self {
		case .ivory:
			return UIColor(red: 0.96, green: 0.96, blue: 0.94, alpha: 1.0)
		case .crimson:
			return UIColor(red: 0.66, green: 0.16, blue: 0.22, alpha: 1.0)
		case .emerald:
			return UIColor(red: 0.16, green: 0.52, blue: 0.33, alpha: 1.0)
		case .sapphire:
			return UIColor(red: 0.16, green: 0.35, blue: 0.67, alpha: 1.0)
		case .amber:
			return UIColor(red: 0.80, green: 0.56, blue: 0.14, alpha: 1.0)
		case .slate:
			return UIColor(red: 0.35, green: 0.40, blue: 0.48, alpha: 1.0)
		}
	}
}

struct DiceDieColorPreferences: Equatable {
	static let supportedSideCounts = [4, 6, 8, 10, 12, 20]

	private(set) var presetsBySideCount: [Int: DiceDieColorPreset]

	init(presetsBySideCount: [Int: DiceDieColorPreset]) {
		self.presetsBySideCount = presetsBySideCount
		for sideCount in Self.supportedSideCounts where self.presetsBySideCount[sideCount] == nil {
			self.presetsBySideCount[sideCount] = .ivory
		}
	}

	static let `default` = DiceDieColorPreferences(presetsBySideCount: [:])

	func preset(for sideCount: Int) -> DiceDieColorPreset {
		presetsBySideCount[sideCount] ?? .ivory
	}

	func fillColor(for sideCount: Int) -> UIColor {
		preset(for: sideCount).fillColor
	}

	func updated(sideCount: Int, preset: DiceDieColorPreset) -> DiceDieColorPreferences {
		var updated = presetsBySideCount
		updated[sideCount] = preset
		return DiceDieColorPreferences(presetsBySideCount: updated)
	}

	func serialized() -> [String: String] {
		var map: [String: String] = [:]
		for sideCount in Self.supportedSideCounts {
			map[String(sideCount)] = preset(for: sideCount).rawValue
		}
		return map
	}

	static func deserialize(_ raw: [String: String]) -> DiceDieColorPreferences {
		var map: [Int: DiceDieColorPreset] = [:]
		for sideCount in supportedSideCounts {
			if let rawValue = raw[String(sideCount)], let preset = DiceDieColorPreset(rawValue: rawValue) {
				map[sideCount] = preset
			}
		}
		return DiceDieColorPreferences(presetsBySideCount: map)
	}
}
