import Foundation

enum DiceBoardLayoutPreset: String, CaseIterable {
	case compact
	case spacious

	var menuTitleKey: String {
		switch self {
		case .compact:
			return "layout.compact"
		case .spacious:
			return "layout.spacious"
		}
	}
}
