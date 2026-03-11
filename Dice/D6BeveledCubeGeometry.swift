import SceneKit

enum D6BeveledCubeGeometry {
	static func make(sideLength: CGFloat) -> SCNBox {
		let box = SCNBox(
			width: sideLength,
			height: sideLength,
			length: sideLength,
			chamferRadius: sideLength * 0.08
		)
		box.chamferSegmentCount = 4
		return box
	}
}
