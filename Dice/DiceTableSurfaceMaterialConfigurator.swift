import Foundation
import SceneKit
import UIKit

enum DiceTableSurfaceMaterialConfigurator {
	private static let neutralTextureName = "stripes"
	private static let neutralTextureImage: UIImage? = {
		#if os(watchOS)
		if let image = UIImage(named: neutralTextureName) {
			return image
		}
		let bundles = [Bundle.main, Bundle(for: BundleToken.self)]
		for bundle in bundles {
			if let url = bundle.url(forResource: neutralTextureName, withExtension: "png"),
			   let data = try? Data(contentsOf: url),
			   let image = UIImage(data: data) {
				return image
			}
		}
		return nil
		#else
		let bundles = [Bundle.main, Bundle(for: BundleToken.self)]
		for bundle in bundles {
			if let image = UIImage(named: neutralTextureName, in: bundle, compatibleWith: nil) {
				return image
			}
		}
		return UIImage(named: neutralTextureName)
		#endif
	}()

	static let neutralTexturePixelSize: CGSize = {
		guard let image = neutralTextureImage else { return .zero }
		if let cgImage = image.cgImage {
			return CGSize(width: cgImage.width, height: cgImage.height)
		}
		return CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
	}()

	static func configureBaseMaterial(_ material: SCNMaterial) {
		material.lightingModel = .lambert
		material.isLitPerPixel = true
		material.isDoubleSided = true
		material.diffuse.wrapS = .repeat
		material.diffuse.wrapT = .repeat
		material.writesToDepthBuffer = true
		material.readsFromDepthBuffer = true
		if let tableShader = DiceShaderModifierSourceLoader.tableSurfaceShaderModifier() {
			material.shaderModifiers = [.surface: tableShader]
		}
	}

	static func applyTexture(_ texture: DiceTableTexture, to material: SCNMaterial, pointScale: CGSize) {
		material.setValue(texture.shaderModeValue, forKey: "tableTextureMode")
		let clampedPointScale = CGSize(width: max(1, pointScale.width), height: max(1, pointScale.height))
		let scale = max(1, min(clampedPointScale.width, clampedPointScale.height))
		material.setValue(scale as NSNumber, forKey: "tableTextureScale")
		material.setValue(clampedPointScale.width as NSNumber, forKey: "tableTextureScaleX")
		material.setValue(clampedPointScale.height as NSNumber, forKey: "tableTextureScaleY")

		switch texture {
		case .neutral:
			material.diffuse.contents = neutralTextureImage
			material.diffuse.minificationFilter = .nearest
			material.diffuse.magnificationFilter = .nearest
			material.diffuse.mipFilter = .none
			applyNeutralContentsTransform(to: material, pointScale: clampedPointScale)
		case .black:
			material.diffuse.contents = UIColor.black
			material.diffuse.minificationFilter = .nearest
			material.diffuse.magnificationFilter = .nearest
			material.diffuse.mipFilter = .none
			material.diffuse.contentsTransform = SCNMatrix4Identity
		case .felt, .wood:
			material.diffuse.contents = UIColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1.0)
			material.diffuse.minificationFilter = .linear
			material.diffuse.magnificationFilter = .linear
			material.diffuse.mipFilter = .none
			material.diffuse.contentsTransform = SCNMatrix4Identity
		}
	}

	private static func applyNeutralContentsTransform(to material: SCNMaterial, pointScale: CGSize) {
		guard neutralTexturePixelSize.width > 0, neutralTexturePixelSize.height > 0 else {
			material.diffuse.contentsTransform = SCNMatrix4Identity
			return
		}
		let repeatX = Float(pointScale.width / neutralTexturePixelSize.width)
		let repeatY = Float(pointScale.height / neutralTexturePixelSize.height)
		material.diffuse.contentsTransform = SCNMatrix4MakeScale(repeatX, repeatY, 1)
	}
}

private final class BundleToken {}
