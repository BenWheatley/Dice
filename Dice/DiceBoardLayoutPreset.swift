import Foundation

enum DiceBoardLayoutPreset: String, CaseIterable {
	case compact
	case balanced
	case spacious

	var menuTitleKey: String {
		switch self {
		case .compact:
			return "layout.compact"
		case .balanced:
			return "layout.balanced"
		case .spacious:
			return "layout.spacious"
		}
	}
}
