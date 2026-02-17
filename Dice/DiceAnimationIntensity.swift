import Foundation

enum DiceAnimationIntensity: String, CaseIterable {
	case off
	case full

	var menuTitleKey: String {
		switch self {
		case .off:
			return "animation.off"
		case .full:
			return "animation.full"
		}
	}
}
