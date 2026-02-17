import Foundation

enum DiceBoardCameraPreset: String, CaseIterable {
	case top
	case slightTilt
	case dramatic

	var menuTitleKey: String {
		switch self {
		case .top:
			return "camera.top"
		case .slightTilt:
			return "camera.slightTilt"
		case .dramatic:
			return "camera.dramatic"
		}
	}
}
