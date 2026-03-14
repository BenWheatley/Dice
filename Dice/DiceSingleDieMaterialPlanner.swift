import Foundation
import SceneKit
#if os(watchOS)
import WatchKit
import SpriteKit
#else
import UIKit
#endif

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
		// Rotate by opposite quarter-turns while preserving winding to avoid mirrored labels.
		let topTransform = centeredTextureTransform(rotation: -.pi / 2, mirrorX: false, scale: 1.04)
		let bottomTransform = centeredTextureTransform(rotation: .pi / 2, mirrorX: false, scale: 1.04)
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

struct DiceFaceTextureSet {
	let diffuse: Any
	let normal: Any
	let metalness: Any
	let roughness: Any
}

enum DiceFaceTextureFactory {
	private static let textureEdgeLength: CGFloat = 256

	private struct CacheKey: Hashable {
		let sideCount: Int
		let value: Int
		let d4VertexLabels: [Int]
		let fillRed: UInt8
		let fillGreen: UInt8
		let fillBlue: UInt8
		let fillAlpha: UInt8
		let fontRawValue: String
		let pipStyleRawValue: String
		let largeLabels: Bool
	}

	private struct FaceValueTextureLayout {
		let numeralSize: CGFloat
		let captionSize: CGFloat
		let numeralYOffset: CGFloat
		let subtitleY: CGFloat
		let drawsBorder: Bool
	}

	private static var cache: [CacheKey: DiceFaceTextureSet] = [:]
	private static let cacheLock = NSLock()

	static func textureSet(
		value rawValue: Int,
		sideCount rawSideCount: Int,
		fillColor: UIColor,
		numeralFont: DiceFaceNumeralFont,
		pipStyle: DiceD6PipStyle,
		largeFaceLabelsEnabled: Bool,
		d4VertexLabels: [Int] = []
	) -> DiceFaceTextureSet {
		let sideCount = DiceSingleDieSceneGeometryFactory.clampedSideCount(rawSideCount)
		let value = max(1, min(sideCount, rawValue))
#if os(watchOS)
		return watchTextureSet(value: value, sideCount: sideCount, fillColor: fillColor)
#else
		if sideCount == 6 {
			let d6 = D6SceneKitRenderConfig.faceTextureSet(value: value, fillColor: fillColor, pipStyle: pipStyle)
			return DiceFaceTextureSet(
				diffuse: d6.diffuse,
				normal: d6.normal,
				metalness: d6.metalness,
				roughness: d6.roughness
			)
		}

		let rgba = rgbaComponents(fillColor)
		let cacheKey = CacheKey(
			sideCount: sideCount,
			value: value,
			d4VertexLabels: d4VertexLabels,
			fillRed: rgba.r,
			fillGreen: rgba.g,
			fillBlue: rgba.b,
			fillAlpha: rgba.a,
			fontRawValue: numeralFont.rawValue,
			pipStyleRawValue: pipStyle.rawValue,
			largeLabels: largeFaceLabelsEnabled
		)
		cacheLock.lock()
		if let cached = cache[cacheKey] {
			cacheLock.unlock()
			return cached
		}
		cacheLock.unlock()

		let generated: DiceFaceTextureSet
		if sideCount == 4, d4VertexLabels.count == 3 {
			generated = d4TextureSet(
				vertexLabels: d4VertexLabels,
				fillColor: fillColor,
				numeralFont: numeralFont,
				largeFaceLabelsEnabled: largeFaceLabelsEnabled
			)
		} else {
			generated = faceValueTextureSet(
				value: value,
				sideCount: sideCount,
				fillColor: fillColor,
				numeralFont: numeralFont,
				largeFaceLabelsEnabled: largeFaceLabelsEnabled
			)
		}

		cacheLock.lock()
		cache[cacheKey] = generated
		cacheLock.unlock()
		return generated
#endif
	}

#if os(watchOS)
	private static func watchTextureSet(value: Int, sideCount: Int, fillColor: UIColor) -> DiceFaceTextureSet {
		let size = CGSize(width: textureEdgeLength, height: textureEdgeLength)
		let scene = SKScene(size: size)
		scene.scaleMode = .resizeFill
		let style = DiceFaceContrast.style(for: fillColor)
		scene.backgroundColor = style.fillColor

		let numeral = SKLabelNode(text: "\(value)")
		numeral.fontName = "SFCompactRounded-Bold"
		numeral.fontSize = sideCount == 2 || DiceSingleDieSceneGeometryFactory.usesTokenGeometry(for: sideCount) ? 138 : 132
		numeral.fontColor = style.primaryInkColor
		numeral.verticalAlignmentMode = .center
		numeral.horizontalAlignmentMode = .center
		numeral.position = CGPoint(x: size.width / 2, y: size.height * 0.53)
		scene.addChild(numeral)

		if sideCount == 2 || DiceSingleDieSceneGeometryFactory.usesTokenGeometry(for: sideCount) {
			let subtitle = SKLabelNode(text: "d\(sideCount)")
			subtitle.fontName = "SFCompactRounded-Semibold"
			subtitle.fontSize = 48
			subtitle.fontColor = style.secondaryInkColor
			subtitle.verticalAlignmentMode = .center
			subtitle.horizontalAlignmentMode = .center
			subtitle.position = CGPoint(x: size.width / 2, y: size.height * 0.20)
			scene.addChild(subtitle)
		}

		return DiceFaceTextureSet(
			diffuse: scene,
			normal: UIColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 1.0),
			metalness: UIColor.black,
			roughness: UIColor(white: 0.88, alpha: 1.0)
		)
	}
#else

	private static func faceValueTextureSet(
		value: Int,
		sideCount: Int,
		fillColor: UIColor,
		numeralFont: DiceFaceNumeralFont,
		largeFaceLabelsEnabled: Bool
	) -> DiceFaceTextureSet {
		let size = CGSize(width: textureEdgeLength, height: textureEdgeLength)
		let rect = CGRect(origin: .zero, size: size)
		let layout = faceValueTextureLayout(sideCount: sideCount, largeFaceLabelsEnabled: largeFaceLabelsEnabled)
		let style = DiceFaceContrast.style(for: fillColor)
		let numeralOutlineColor = oppositeInkColor(for: style.primaryInkColor)
		let captionOutlineColor = oppositeInkColor(for: style.secondaryInkColor)
		let numeralSize = layout.numeralSize
		let captionSize = layout.captionSize
		let numeralOutlineWidth = max(1.4, numeralSize * 0.075)
		let captionOutlineWidth = max(1.0, captionSize * 0.08)
		let text = "\(value)" as NSString
		let subtitle = "d\(sideCount)" as NSString

		func drawText(attributes: [NSAttributedString.Key: Any], subtitleAttributes: [NSAttributedString.Key: Any]) {
			let tSize = text.size(withAttributes: attributes)
			let tRect = CGRect(
				x: (size.width - tSize.width) / 2,
				y: (size.height - tSize.height) / 2 + layout.numeralYOffset,
				width: tSize.width,
				height: tSize.height
			)
			text.draw(in: tRect, withAttributes: attributes)

			let sSize = subtitle.size(withAttributes: subtitleAttributes)
			let sRect = CGRect(
				x: (size.width - sSize.width) / 2,
				y: layout.subtitleY,
				width: sSize.width,
				height: sSize.height
			)
			subtitle.draw(in: sRect, withAttributes: subtitleAttributes)
		}

		let symbolFillMask = UIGraphicsImageRenderer(size: size).image { context in
			UIColor.black.setFill()
			context.cgContext.fill(rect)
			drawText(
				attributes: [
					.font: numeralFont.numeralFont(ofSize: numeralSize),
					.foregroundColor: UIColor.white
				],
				subtitleAttributes: [
					.font: numeralFont.captionFont(ofSize: captionSize),
					.foregroundColor: UIColor.white
				]
			)
		}
		let symbolOutlineMask = UIGraphicsImageRenderer(size: size).image { context in
			UIColor.black.setFill()
			context.cgContext.fill(rect)
			drawText(
				attributes: [
					.font: numeralFont.numeralFont(ofSize: numeralSize),
					.foregroundColor: UIColor.clear,
					.strokeColor: UIColor.white,
					.strokeWidth: numeralOutlineWidth
				],
				subtitleAttributes: [
					.font: numeralFont.captionFont(ofSize: captionSize),
					.foregroundColor: UIColor.clear,
					.strokeColor: UIColor.white,
					.strokeWidth: captionOutlineWidth
				]
			)
		}

		let diffuse = UIGraphicsImageRenderer(size: size).image { context in
			context.cgContext.setFillColor(style.fillColor.cgColor)
			context.cgContext.fill(rect)
			if layout.drawsBorder {
				context.cgContext.setStrokeColor(style.borderColor.cgColor)
				context.cgContext.setLineWidth(8)
				context.cgContext.stroke(rect.insetBy(dx: 6, dy: 6))
			}
			drawText(
				attributes: [
					.font: numeralFont.numeralFont(ofSize: numeralSize),
					.foregroundColor: style.primaryInkColor,
					.strokeColor: numeralOutlineColor,
					.strokeWidth: -numeralOutlineWidth
				],
				subtitleAttributes: [
					.font: numeralFont.captionFont(ofSize: captionSize),
					.foregroundColor: style.secondaryInkColor,
					.strokeColor: captionOutlineColor,
					.strokeWidth: -captionOutlineWidth
				]
			)
		}

		let normal = D6SceneKitRenderConfig.flatNormalMapImage()
		return DiceFaceTextureSet(diffuse: diffuse, normal: normal, metalness: symbolOutlineMask, roughness: symbolFillMask)
	}

	private static func d4TextureSet(
		vertexLabels: [Int],
		fillColor: UIColor,
		numeralFont: DiceFaceNumeralFont,
		largeFaceLabelsEnabled: Bool
	) -> DiceFaceTextureSet {
		let size = CGSize(width: textureEdgeLength, height: textureEdgeLength)
		let rect = CGRect(origin: .zero, size: size)
		let style = DiceFaceContrast.style(for: fillColor)
		let outlineInkColor = oppositeInkColor(for: style.primaryInkColor)
		let trianglePoints = d4TrianglePoints(size: size)
		let placements = d4LabelPlacements(triangle: trianglePoints)
		let numeralSize = DiceFaceLabelSizing.textureNumeralPointSize(sideCount: 4, large: largeFaceLabelsEnabled)
		let numeralOutlineWidth = max(1.6, numeralSize * 0.075)

		let drawLabels: (_ context: CGContext, _ attributes: [NSAttributedString.Key: Any]) -> Void = { context, attributes in
			for (index, placement) in placements.enumerated() where index < vertexLabels.count {
				let text = "\(vertexLabels[index])" as NSString
				let textSize = text.size(withAttributes: attributes)
				let textRect = CGRect(
					x: -textSize.width / 2,
					y: -textSize.height / 2,
					width: textSize.width,
					height: textSize.height
				)
				context.saveGState()
				context.translateBy(x: placement.position.x, y: placement.position.y)
				context.rotate(by: placement.angle)
				text.draw(in: textRect, withAttributes: attributes)
				context.restoreGState()
			}
		}

		let symbolFillMask = UIGraphicsImageRenderer(size: size).image { context in
			UIColor.black.setFill()
			context.cgContext.fill(rect)
			let attrs: [NSAttributedString.Key: Any] = [
				.font: numeralFont.numeralFont(ofSize: numeralSize),
				.foregroundColor: UIColor.white
			]
			drawLabels(context.cgContext, attrs)
		}
		let symbolOutlineMask = UIGraphicsImageRenderer(size: size).image { context in
			UIColor.black.setFill()
			context.cgContext.fill(rect)
			let attrs: [NSAttributedString.Key: Any] = [
				.font: numeralFont.numeralFont(ofSize: numeralSize),
				.foregroundColor: UIColor.clear,
				.strokeColor: UIColor.white,
				.strokeWidth: numeralOutlineWidth
			]
			drawLabels(context.cgContext, attrs)
		}

		let diffuse = UIGraphicsImageRenderer(size: size).image { _ in
			let triangle = UIBezierPath()
			triangle.move(to: trianglePoints[0])
			triangle.addLine(to: trianglePoints[1])
			triangle.addLine(to: trianglePoints[2])
			triangle.close()
			style.fillColor.setFill()
			triangle.fill()
			style.borderColor.setStroke()
			triangle.lineWidth = 6
			triangle.stroke()

			let attrs: [NSAttributedString.Key: Any] = [
				.font: numeralFont.numeralFont(ofSize: numeralSize),
				.foregroundColor: style.primaryInkColor,
				.strokeColor: outlineInkColor,
				.strokeWidth: -numeralOutlineWidth
			]
			if let context = UIGraphicsGetCurrentContext() {
				drawLabels(context, attrs)
			}
		}

		let normal = D6SceneKitRenderConfig.flatNormalMapImage()
		return DiceFaceTextureSet(diffuse: diffuse, normal: normal, metalness: symbolOutlineMask, roughness: symbolFillMask)
	}

	private static func faceValueTextureLayout(sideCount: Int, largeFaceLabelsEnabled: Bool) -> FaceValueTextureLayout {
		let isCylindricalFace =
			DiceSingleDieSceneGeometryFactory.usesCoinGeometry(for: sideCount)
			|| DiceSingleDieSceneGeometryFactory.usesTokenGeometry(for: sideCount)
		let baseNumeralSize = DiceFaceLabelSizing.textureNumeralPointSize(sideCount: sideCount, large: largeFaceLabelsEnabled)
		if isCylindricalFace {
			let numeralSize = baseNumeralSize * 1.08
			return FaceValueTextureLayout(
				numeralSize: numeralSize,
				captionSize: numeralSize * 0.5,
				numeralYOffset: -textureEdgeLength * 0.09,
				subtitleY: textureEdgeLength * 0.72,
				drawsBorder: false
			)
		}
		let captionSize = DiceFaceLabelSizing.textureCaptionPointSize(large: largeFaceLabelsEnabled)
		return FaceValueTextureLayout(
			numeralSize: baseNumeralSize,
			captionSize: captionSize,
			numeralYOffset: -textureEdgeLength * 0.08,
			subtitleY: textureEdgeLength * 0.74,
			drawsBorder: sideCount == 6
		)
	}

	private static func d4TrianglePoints(size: CGSize) -> [CGPoint] {
		[
			CGPoint(x: size.width * 0.50, y: size.height * 0.10),
			CGPoint(x: size.width * 0.14, y: size.height * 0.86),
			CGPoint(x: size.width * 0.86, y: size.height * 0.86),
		]
	}

	private static func d4LabelPlacements(triangle: [CGPoint]) -> [(position: CGPoint, angle: CGFloat)] {
		guard triangle.count == 3 else { return [] }
		let inset: CGFloat = 0.34
		return (0..<3).map { index in
			let vertex = triangle[index]
			let otherA = triangle[(index + 1) % 3]
			let otherB = triangle[(index + 2) % 3]
			let oppositeMid = CGPoint(x: (otherA.x + otherB.x) * 0.5, y: (otherA.y + otherB.y) * 0.5)
			let towardOpposite = CGPoint(x: oppositeMid.x - vertex.x, y: oppositeMid.y - vertex.y)
			let position = CGPoint(
				x: vertex.x + towardOpposite.x * inset,
				y: vertex.y + towardOpposite.y * inset
			)
			let angle = atan2(towardOpposite.y, towardOpposite.x) - (.pi / 2)
			return (position: position, angle: angle)
		}
	}

	private static func oppositeInkColor(for inkColor: UIColor) -> UIColor {
		inkColor.diceRelativeLuminance >= 0.5 ? .black : .white
	}

	private static func rgbaComponents(_ color: UIColor) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
		var red: CGFloat = 0
		var green: CGFloat = 0
		var blue: CGFloat = 0
		var alpha: CGFloat = 0
		if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
			return (
				r: UInt8((red * 255).rounded()),
				g: UInt8((green * 255).rounded()),
				b: UInt8((blue * 255).rounded()),
				a: UInt8((alpha * 255).rounded())
			)
		}
		var white: CGFloat = 0
		if color.getWhite(&white, alpha: &alpha) {
			let channel = UInt8((white * 255).rounded())
			return (r: channel, g: channel, b: channel, a: UInt8((alpha * 255).rounded()))
		}
		return (r: 245, g: 245, b: 245, a: 255)
	}
#endif
}

private extension UIColor {
	var diceRelativeLuminance: CGFloat {
		var red: CGFloat = 0
		var green: CGFloat = 0
		var blue: CGFloat = 0
		var alpha: CGFloat = 0
		if getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
			return (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
		}
		var white: CGFloat = 0
		if getWhite(&white, alpha: &alpha) {
			return white
		}
		return 0.0
	}
}
