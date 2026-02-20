import UIKit

enum DiceTableTexture: String, CaseIterable {
	case felt
	case wood
	case neutral

	var menuTitleKey: String {
		switch self {
		case .felt:
			return "texture.felt"
		case .wood:
			return "texture.wood"
		case .neutral:
			return "texture.neutral"
		}
	}
}
