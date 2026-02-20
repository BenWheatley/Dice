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

	var notationName: String {
		switch self {
		case .crimson:
			return "red"
		case .emerald:
			return "green"
		case .sapphire:
			return "blue"
		default:
			return rawValue
		}
	}

	static func fromNotation(_ raw: String) -> DiceDieColorPreset? {
		switch raw.lowercased() {
		case "red":
			return .crimson
		case "green":
			return .emerald
		case "blue":
			return .sapphire
		default:
			return DiceDieColorPreset(rawValue: raw.lowercased())
		}
	}
}
