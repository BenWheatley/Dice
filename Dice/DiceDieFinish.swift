import SceneKit
import UIKit

enum DiceDieFinish: String, CaseIterable {
	case matte
	case gloss
	case stone

	var menuTitleKey: String {
		switch self {
		case .matte:
			return "finish.matte"
		case .gloss:
			return "finish.gloss"
		case .stone:
			return "finish.stone"
		}
	}

	func apply(to material: SCNMaterial) {
		apply(to: material, baseColor: nil, dieIndex: 0)
	}

	func apply(to material: SCNMaterial, baseColor: UIColor?, dieIndex: Int) {
		switch self {
		case .matte:
			material.lightingModel = .lambert
			material.specular.contents = UIColor(white: 0.15, alpha: 1.0)
			material.shininess = 0.08
		case .gloss:
			material.lightingModel = .blinn
			material.specular.contents = UIColor(white: 0.95, alpha: 1.0)
			material.shininess = 0.90
		case .stone:
			material.lightingModel = .lambert
			material.specular.contents = UIColor(white: 0.25, alpha: 1.0)
			_ = baseColor
			// Encode a stable per-die seed in shininess (read back by shader).
			material.shininess = 0.20 + CGFloat(dieIndex) * 0.0001
		}

		if let surfaceSource = DiceShaderModifierSourceLoader.surfaceShaderModifier(forStoneFinish: self == .stone) {
			material.shaderModifiers = [.surface: surfaceSource]
		} else {
			material.shaderModifiers = nil
		}
	}
}
