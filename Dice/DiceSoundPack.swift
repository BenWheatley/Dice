import Foundation

enum DiceSoundPack: String, CaseIterable {
	case off
	case softWood
	case hardTable

	var menuTitleKey: String {
		switch self {
		case .off:
			return "soundPack.off"
		case .softWood:
			return "soundPack.softWood"
		case .hardTable:
			return "soundPack.hardTable"
		}
	}
}
