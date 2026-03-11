import Foundation
import SceneKit

enum DiceSingleDieMaterialSlot: Equatable {
	case side
	case face(value: Int)
}

struct DiceSingleDieMaterialPlan: Equatable {
	let slots: [DiceSingleDieMaterialSlot]
	let appliesCylindricalCapUVCompensation: Bool
}

enum DiceSingleDieMaterialPlanner {
	static func makePlan(sideCount rawSideCount: Int, currentValue: Int, faceValueCount: Int) -> DiceSingleDieMaterialPlan {
		let sideCount = DiceSingleDieSceneGeometryFactory.clampedSideCount(rawSideCount)
		if DiceSingleDieSceneGeometryFactory.usesCoinGeometry(for: sideCount) {
			return DiceSingleDieMaterialPlan(
				slots: [.side, .face(value: 1), .face(value: 2)],
				appliesCylindricalCapUVCompensation: true
			)
		}
		if DiceSingleDieSceneGeometryFactory.usesTokenGeometry(for: sideCount) {
			let value = max(1, min(sideCount, currentValue))
			return DiceSingleDieMaterialPlan(
				slots: [.side, .face(value: value), .face(value: value)],
				appliesCylindricalCapUVCompensation: true
			)
		}
		let count = max(1, faceValueCount)
		let slots = (1...count).map { DiceSingleDieMaterialSlot.face(value: $0) }
		return DiceSingleDieMaterialPlan(
			slots: slots,
			appliesCylindricalCapUVCompensation: false
		)
	}

	static func applyCylindricalCapTextureCompensation(top: SCNMaterial, bottom: SCNMaterial) {
		// SceneKit cylinder cap UVs are quarter-turned relative to upright symbols.
		// Rotate by opposite quarter-turns and mirror to keep symbols centered and non-mirrored.
		let topTransform = centeredTextureTransform(rotation: -.pi / 2, mirrorX: true, scale: 1.04)
		let bottomTransform = centeredTextureTransform(rotation: .pi / 2, mirrorX: true, scale: 1.04)
		applyTextureTransform(topTransform, to: top)
		applyTextureTransform(bottomTransform, to: bottom)
	}

	private static func applyTextureTransform(_ transform: SCNMatrix4, to material: SCNMaterial) {
		material.diffuse.contentsTransform = transform
		material.normal.contentsTransform = transform
		material.specular.contentsTransform = transform
		material.metalness.contentsTransform = transform
		material.roughness.contentsTransform = transform
	}

	private static func centeredTextureTransform(rotation: Float, mirrorX: Bool = false, scale: Float = 1) -> SCNMatrix4 {
		let toCenter = SCNMatrix4MakeTranslation(0.5, 0.5, 0)
		let rotate = SCNMatrix4MakeRotation(rotation, 0, 0, 1)
		let mirror = SCNMatrix4MakeScale(mirrorX ? -1 : 1, 1, 1)
		let scaleMatrix = SCNMatrix4MakeScale(scale, scale, 1)
		let fromCenter = SCNMatrix4MakeTranslation(-0.5, -0.5, 0)
		let oriented = SCNMatrix4Mult(rotate, mirror)
		let transformed = SCNMatrix4Mult(oriented, scaleMatrix)
		return SCNMatrix4Mult(SCNMatrix4Mult(fromCenter, transformed), toCenter)
	}
}
