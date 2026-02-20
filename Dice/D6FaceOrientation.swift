import Foundation

struct D6FaceOrientation {
	static func eulerAngles(for value: Int) -> (x: Float, y: Float, z: Float) {
		switch value {
		case 1:
			return (0, 0, 0)
		case 2:
			return (0, -Float.pi / 2, 0)
		case 3:
			return (0, Float.pi, 0)
		case 4:
			return (0, Float.pi / 2, 0)
		case 5:
			return (Float.pi / 2, 0, 0)
		case 6:
			return (-Float.pi / 2, 0, 0)
		default:
			return (0, 0, 0)
		}
	}
}
