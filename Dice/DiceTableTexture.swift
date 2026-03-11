import Foundation

enum DiceTableTexture: String, CaseIterable {
	case felt
	case wood
	case neutral
	case black

	var shaderModeValue: NSNumber {
		switch self {
		case .felt:
			return NSNumber(value: 0)
		case .wood:
			return NSNumber(value: 1)
		case .neutral:
			return NSNumber(value: 2)
		case .black:
			return NSNumber(value: 3)
		}
	}

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
