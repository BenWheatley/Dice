import Foundation

enum DiceTableTexture: String, CaseIterable {
	case felt
	case wood
	case neutral
	case black

	var menuTitleKey: String {
		switch self {
		case .felt:
			return "texture.felt"
		case .wood:
			return "texture.wood"
		case .neutral:
			return "texture.neutral"
		case .black:
			return "texture.black"
		}
	}
}
