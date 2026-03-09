import Foundation

enum DiceLightingAngle: String, CaseIterable {
	case natural
	case fixed

	var menuTitleKey: String {
		switch self {
		case .natural:
			return "lighting.natural"
		case .fixed:
			return "lighting.fixed"
		}
	}
}
