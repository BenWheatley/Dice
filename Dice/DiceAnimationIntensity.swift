import Foundation

enum DiceAnimationIntensity: String, CaseIterable {
	case off
	case subtle
	case full

	var menuTitleKey: String {
		switch self {
		case .off:
			return "animation.off"
		case .subtle:
			return "animation.subtle"
		case .full:
			return "animation.full"
		}
	}
}
