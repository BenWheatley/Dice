import Foundation
import SceneKit
import CoreGraphics
import CoreText
#if os(watchOS)
import WatchKit
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
		// SceneKit cylinder caps are quarter-turned and mirrored relative to our shared CGImage textures.
		// Compensate with opposite quarter-turns plus an X reflection so symbols read correctly.
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

	private struct GlyphPathData {
		let path: CGPath
		let bounds: CGRect
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
	private static let flatNormalTexture: CGImage = makeSolidImage(
		size: CGSize(width: 1, height: 1),
		color: UIColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 1.0)
	)

	private static let d6PipPositions: [CGPoint] = [
		CGPoint(x: textureEdgeLength * 0.28, y: textureEdgeLength * 0.28),
		CGPoint(x: textureEdgeLength * 0.50, y: textureEdgeLength * 0.28),
		CGPoint(x: textureEdgeLength * 0.72, y: textureEdgeLength * 0.28),
		CGPoint(x: textureEdgeLength * 0.28, y: textureEdgeLength * 0.50),
		CGPoint(x: textureEdgeLength * 0.50, y: textureEdgeLength * 0.50),
		CGPoint(x: textureEdgeLength * 0.72, y: textureEdgeLength * 0.50),
		CGPoint(x: textureEdgeLength * 0.28, y: textureEdgeLength * 0.72),
		CGPoint(x: textureEdgeLength * 0.50, y: textureEdgeLength * 0.72),
		CGPoint(x: textureEdgeLength * 0.72, y: textureEdgeLength * 0.72),
	]

	private static let d6PipIndicesByValue: [Int: [Int]] = [
		1: [4],
		2: [0, 8],
		3: [0, 4, 8],
		4: [0, 2, 6, 8],
		5: [0, 2, 4, 6, 8],
		6: [0, 2, 3, 5, 6, 8],
	]

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
		if sideCount == 6 {
			generated = d6TextureSet(value: value, fillColor: fillColor, pipStyle: pipStyle)
		} else if sideCount == 4, d4VertexLabels.count == 3 {
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
	}

	static func flatNormalMap() -> CGImage {
		flatNormalTexture
	}

	private static func d6TextureSet(
		value: Int,
		fillColor: UIColor,
		pipStyle: DiceD6PipStyle
	) -> DiceFaceTextureSet {
		let size = CGSize(width: textureEdgeLength, height: textureEdgeLength)
		let style = DiceFaceContrast.style(for: fillColor)
		let outlineColor = oppositeInkColor(for: style.primaryInkColor)
		let radius = size.width * 0.08
		let outlineWidth = radius * 0.20

		let diffuse = makeImage(size: size) { context in
			context.setFillColor(style.fillColor.cgColor)
			context.fill(CGRect(origin: .zero, size: size))
			for index in d6PipIndicesByValue[value] ?? [] {
				let center = d6PipPositions[index]
				drawPip(
					context: context,
					centerTopLeft: center,
					radius: radius,
					pipStyle: pipStyle,
					canvasSize: size,
					fillColor: style.primaryInkColor.cgColor
				)
				drawPipRing(
					context: context,
					centerTopLeft: center,
					radius: radius,
					ringWidth: outlineWidth,
					pipStyle: pipStyle,
					canvasSize: size,
					ringColor: outlineColor.cgColor
				)
			}
		}

		let symbolFillMask = makeImage(size: size) { context in
			context.setFillColor(UIColor.black.cgColor)
			context.fill(CGRect(origin: .zero, size: size))
			for index in d6PipIndicesByValue[value] ?? [] {
				drawPip(
					context: context,
					centerTopLeft: d6PipPositions[index],
					radius: radius,
					pipStyle: pipStyle,
					canvasSize: size,
					fillColor: UIColor.white.cgColor
				)
			}
		}

		let symbolOutlineMask = makeImage(size: size) { context in
			context.setFillColor(UIColor.black.cgColor)
			context.fill(CGRect(origin: .zero, size: size))
			for index in d6PipIndicesByValue[value] ?? [] {
				drawPipRing(
					context: context,
					centerTopLeft: d6PipPositions[index],
					radius: radius,
					ringWidth: outlineWidth,
					pipStyle: pipStyle,
					canvasSize: size,
					ringColor: UIColor.white.cgColor
				)
			}
		}

		return DiceFaceTextureSet(
			diffuse: diffuse,
			normal: flatNormalTexture,
			metalness: symbolOutlineMask,
			roughness: symbolFillMask
		)
	}
    
    private static func showsCaption(sideCount: Int) -> Bool {
        !([4,6,8,10,12,20].contains { $0 == sideCount })
    }

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
		let numeralText = "\(value)"
        let captionText = showsCaption(sideCount: sideCount) ? "d\(sideCount)" : ""
		let numeralFontRef = numeralFont.numeralFont(ofSize: numeralSize)
		let captionFontRef = numeralFont.captionFont(ofSize: captionSize)

		let symbolFillMask = makeImage(size: size) { context in
			context.setFillColor(UIColor.black.cgColor)
			context.fill(rect)
			drawCenteredText(
				numeralText,
				font: numeralFontRef,
				centerTopLeft: CGPoint(x: size.width * 0.5, y: (size.height * 0.5) + layout.numeralYOffset),
				canvasSize: size,
				fillColor: UIColor.white.cgColor,
				in: context
			)
			drawTextWithTopOrigin(
				captionText,
				font: captionFontRef,
				topY: layout.subtitleY,
				canvasSize: size,
				fillColor: UIColor.white.cgColor,
				in: context
			)
		}

		let symbolOutlineMask = makeImage(size: size) { context in
			context.setFillColor(UIColor.black.cgColor)
			context.fill(rect)
			drawCenteredText(
				numeralText,
				font: numeralFontRef,
				centerTopLeft: CGPoint(x: size.width * 0.5, y: (size.height * 0.5) + layout.numeralYOffset),
				canvasSize: size,
				fillColor: UIColor.black.cgColor,
				strokeColor: UIColor.white.cgColor,
				strokeWidth: numeralOutlineWidth,
				in: context
			)
			drawTextWithTopOrigin(
				captionText,
				font: captionFontRef,
				topY: layout.subtitleY,
				canvasSize: size,
				fillColor: UIColor.black.cgColor,
				strokeColor: UIColor.white.cgColor,
				strokeWidth: captionOutlineWidth,
				in: context
			)
		}

		let diffuse = makeImage(size: size) { context in
			context.setFillColor(style.fillColor.cgColor)
			context.fill(rect)
			if layout.drawsBorder {
				context.setStrokeColor(style.borderColor.cgColor)
				context.setLineWidth(8)
				context.stroke(rect.insetBy(dx: 6, dy: 6))
			}

			drawCenteredText(
				numeralText,
				font: numeralFontRef,
				centerTopLeft: CGPoint(x: size.width * 0.5, y: (size.height * 0.5) + layout.numeralYOffset),
				canvasSize: size,
				fillColor: style.primaryInkColor.cgColor,
				strokeColor: numeralOutlineColor.cgColor,
				strokeWidth: numeralOutlineWidth,
				in: context
			)
			drawTextWithTopOrigin(
				captionText,
				font: captionFontRef,
				topY: layout.subtitleY,
				canvasSize: size,
				fillColor: style.secondaryInkColor.cgColor,
				strokeColor: captionOutlineColor.cgColor,
				strokeWidth: captionOutlineWidth,
				in: context
			)
		}

		return DiceFaceTextureSet(
			diffuse: diffuse,
			normal: flatNormalTexture,
			metalness: symbolOutlineMask,
			roughness: symbolFillMask
		)
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
		let numeralFontRef = numeralFont.numeralFont(ofSize: numeralSize)

		let symbolFillMask = makeImage(size: size) { context in
			context.setFillColor(UIColor.black.cgColor)
			context.fill(rect)
			for (index, placement) in placements.enumerated() where index < vertexLabels.count {
				drawCenteredText(
					"\(vertexLabels[index])",
					font: numeralFontRef,
					centerTopLeft: placement.position,
					canvasSize: size,
					fillColor: UIColor.white.cgColor,
					rotation: placement.angle,
					in: context
				)
			}
		}

		let symbolOutlineMask = makeImage(size: size) { context in
			context.setFillColor(UIColor.black.cgColor)
			context.fill(rect)
			for (index, placement) in placements.enumerated() where index < vertexLabels.count {
				drawCenteredText(
					"\(vertexLabels[index])",
					font: numeralFontRef,
					centerTopLeft: placement.position,
					canvasSize: size,
					fillColor: UIColor.black.cgColor,
					strokeColor: UIColor.white.cgColor,
					strokeWidth: numeralOutlineWidth,
					rotation: placement.angle,
					in: context
				)
			}
		}

		let diffuse = makeImage(size: size) { context in
			let converted = trianglePoints.map { quartzPoint(fromTopLeft: $0, in: size) }
			context.beginPath()
			context.move(to: converted[0])
			context.addLine(to: converted[1])
			context.addLine(to: converted[2])
			context.closePath()
			context.setFillColor(style.fillColor.cgColor)
			context.fillPath()

			context.beginPath()
			context.move(to: converted[0])
			context.addLine(to: converted[1])
			context.addLine(to: converted[2])
			context.closePath()
			context.setStrokeColor(style.borderColor.cgColor)
			context.setLineWidth(6)
			context.strokePath()

			for (index, placement) in placements.enumerated() where index < vertexLabels.count {
				drawCenteredText(
					"\(vertexLabels[index])",
					font: numeralFontRef,
					centerTopLeft: placement.position,
					canvasSize: size,
					fillColor: style.primaryInkColor.cgColor,
					strokeColor: outlineInkColor.cgColor,
					strokeWidth: numeralOutlineWidth,
					rotation: placement.angle,
					in: context
				)
			}
		}

		return DiceFaceTextureSet(
			diffuse: diffuse,
			normal: flatNormalTexture,
			metalness: symbolOutlineMask,
			roughness: symbolFillMask
		)
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
				numeralYOffset: 0,
				subtitleY: textureEdgeLength * 0.72,
				drawsBorder: false
			)
		}
		let captionSize = DiceFaceLabelSizing.textureCaptionPointSize(large: largeFaceLabelsEnabled)
		return FaceValueTextureLayout(
			numeralSize: baseNumeralSize,
			captionSize: captionSize,
			numeralYOffset: 0,
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

	private static func makeSolidImage(size: CGSize, color: UIColor) -> CGImage {
		makeImage(size: size) { context in
			context.setFillColor(color.cgColor)
			context.fill(CGRect(origin: .zero, size: size))
		}
	}

	private static func makeImage(size: CGSize, draw: (CGContext) -> Void) -> CGImage {
		let width = max(1, Int(size.width.rounded(.toNearestOrAwayFromZero)))
		let height = max(1, Int(size.height.rounded(.toNearestOrAwayFromZero)))
		let colorSpace = CGColorSpaceCreateDeviceRGB()
		guard let context = CGContext(
			data: nil,
			width: width,
			height: height,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: colorSpace,
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else {
			fatalError("Failed to create texture bitmap context")
		}
		context.interpolationQuality = .high
		context.setAllowsAntialiasing(true)
		context.setShouldAntialias(true)
		draw(context)
		guard let image = context.makeImage() else {
			fatalError("Failed to create texture image")
		}
		return image
	}

	private static func drawTextWithTopOrigin(
		_ text: String,
		font: UIFont,
		topY: CGFloat,
		canvasSize: CGSize,
		fillColor: CGColor?,
		strokeColor: CGColor? = nil,
		strokeWidth: CGFloat = 0,
		in context: CGContext
	) {
		guard let glyph = glyphPath(for: text, font: font) else { return }
		let centerY = topY + (glyph.bounds.height * 0.5)
		drawGlyph(
			glyph,
			centerTopLeft: CGPoint(x: canvasSize.width * 0.5, y: centerY),
			canvasSize: canvasSize,
			fillColor: fillColor,
			strokeColor: strokeColor,
			strokeWidth: strokeWidth,
			in: context
		)
	}

	private static func drawCenteredText(
		_ text: String,
		font: UIFont,
		centerTopLeft: CGPoint,
		canvasSize: CGSize,
		fillColor: CGColor?,
		strokeColor: CGColor? = nil,
		strokeWidth: CGFloat = 0,
		rotation: CGFloat = 0,
		in context: CGContext
	) {
		guard let glyph = glyphPath(for: text, font: font) else { return }
		drawGlyph(
			glyph,
			centerTopLeft: centerTopLeft,
			canvasSize: canvasSize,
			fillColor: fillColor,
			strokeColor: strokeColor,
			strokeWidth: strokeWidth,
			rotation: rotation,
			in: context
		)
	}

	private static func drawGlyph(
		_ glyph: GlyphPathData,
		centerTopLeft: CGPoint,
		canvasSize: CGSize,
		fillColor: CGColor?,
		strokeColor: CGColor? = nil,
		strokeWidth: CGFloat = 0,
		rotation: CGFloat = 0,
		in context: CGContext
	) {
		var transform = CGAffineTransform.identity
		let center = quartzPoint(fromTopLeft: centerTopLeft, in: canvasSize)
		transform = transform.translatedBy(x: center.x, y: center.y)
		if rotation != 0 {
			transform = transform.rotated(by: -rotation)
		}
		transform = transform.translatedBy(x: -glyph.bounds.midX, y: -glyph.bounds.midY)
		guard let positionedPath = glyph.path.copy(using: &transform) else { return }

		if let strokeColor, strokeWidth > 0 {
			context.saveGState()
			context.addPath(positionedPath)
			context.setStrokeColor(strokeColor)
			context.setLineWidth(strokeWidth)
			context.setLineJoin(.round)
			context.setLineCap(.round)
			context.strokePath()
			context.restoreGState()
		}

		if let fillColor {
			context.saveGState()
			context.addPath(positionedPath)
			context.setFillColor(fillColor)
			context.fillPath()
			context.restoreGState()
		}
	}

	private static func glyphPath(for text: String, font: UIFont) -> GlyphPathData? {
		guard !text.isEmpty else { return nil }
		// Preserve the platform-resolved UIFont exactly; recreating by name can fall back to serif faces.
		let ctFont = font as CTFont
		var characters = Array(text.utf16)
		var glyphs = Array(repeating: CGGlyph(), count: characters.count)
		guard CTFontGetGlyphsForCharacters(ctFont, &characters, &glyphs, glyphs.count) else {
			return nil
		}

		var advances = Array(repeating: CGSize.zero, count: glyphs.count)
		CTFontGetAdvancesForGlyphs(ctFont, .horizontal, glyphs, &advances, glyphs.count)
		let path = CGMutablePath()
		var xOffset: CGFloat = 0
		for (index, glyph) in glyphs.enumerated() {
			defer { xOffset += advances[index].width }
			guard let glyphPath = CTFontCreatePathForGlyph(ctFont, glyph, nil) else { continue }
			let transform = CGAffineTransform(translationX: xOffset, y: 0)
			path.addPath(glyphPath, transform: transform)
		}

		let bounds = path.boundingBoxOfPath
		return GlyphPathData(path: path.copy() ?? path, bounds: bounds)
	}

	private static func drawPip(
		context: CGContext,
		centerTopLeft: CGPoint,
		radius: CGFloat,
		pipStyle: DiceD6PipStyle,
		canvasSize: CGSize,
		fillColor: CGColor
	) {
		let path = pipPath(
			centerTopLeft: centerTopLeft,
			radius: radius,
			pipStyle: pipStyle,
			canvasSize: canvasSize
		)
		context.saveGState()
		context.addPath(path)
		context.setFillColor(fillColor)
		context.fillPath()
		context.restoreGState()
	}

	private static func drawPipRing(
		context: CGContext,
		centerTopLeft: CGPoint,
		radius: CGFloat,
		ringWidth: CGFloat,
		pipStyle: DiceD6PipStyle,
		canvasSize: CGSize,
		ringColor: CGColor
	) {
		let outerPath = pipPath(
			centerTopLeft: centerTopLeft,
			radius: radius + ringWidth,
			pipStyle: pipStyle,
			canvasSize: canvasSize
		)
		let innerPath = pipPath(
			centerTopLeft: centerTopLeft,
			radius: radius,
			pipStyle: pipStyle,
			canvasSize: canvasSize
		)
		context.saveGState()
		context.addPath(outerPath)
		context.addPath(innerPath)
		context.setFillColor(ringColor)
		context.drawPath(using: .eoFill)
		context.restoreGState()
	}

	private static func pipPath(
		centerTopLeft: CGPoint,
		radius: CGFloat,
		pipStyle: DiceD6PipStyle,
		canvasSize: CGSize
	) -> CGPath {
		let center = quartzPoint(fromTopLeft: centerTopLeft, in: canvasSize)
		let rect = CGRect(
			x: center.x - radius,
			y: center.y - radius,
			width: radius * 2,
			height: radius * 2
		)
		switch pipStyle {
		case .round:
			return CGPath(ellipseIn: rect, transform: nil)
		case .square:
			return CGPath(rect: rect.insetBy(dx: radius * 0.08, dy: radius * 0.08), transform: nil)
		}
	}

	private static func quartzPoint(fromTopLeft point: CGPoint, in canvasSize: CGSize) -> CGPoint {
		CGPoint(x: point.x, y: canvasSize.height - point.y)
	}
}

enum DiceSingleDieMaterialFactory {
	static func makeFaceMaterial(
		value rawValue: Int,
		sideCount rawSideCount: Int,
		fillColor: UIColor,
		numeralFont: DiceFaceNumeralFont,
		pipStyle: DiceD6PipStyle,
		largeFaceLabelsEnabled: Bool,
		d4VertexLabels: [Int] = [],
		dieFinish: DiceDieFinish,
		dieIndex: Int
	) -> SCNMaterial {
		let sideCount = DiceSingleDieSceneGeometryFactory.clampedSideCount(rawSideCount)
		let value = max(1, min(sideCount, rawValue))
		let textureSet = DiceFaceTextureFactory.textureSet(
			value: value,
			sideCount: sideCount,
			fillColor: fillColor,
			numeralFont: numeralFont,
			pipStyle: pipStyle,
			largeFaceLabelsEnabled: largeFaceLabelsEnabled,
			d4VertexLabels: d4VertexLabels
		)

		let material = SCNMaterial()
		material.diffuse.contents = textureSet.diffuse
		material.normal.contents = textureSet.normal
		material.normal.intensity = 0.95
		material.specular.contents = textureSet.metalness
		material.metalness.contents = textureSet.metalness
		material.roughness.contents = textureSet.roughness
		material.diffuse.wrapS = .clamp
		material.diffuse.wrapT = .clamp
		material.normal.wrapS = .clamp
		material.normal.wrapT = .clamp
		material.specular.wrapS = .clamp
		material.specular.wrapT = .clamp
		material.metalness.wrapS = .clamp
		material.metalness.wrapT = .clamp
		material.roughness.wrapS = .clamp
		material.roughness.wrapT = .clamp
		// Keep symbol masks crisp; filtered+mipped mask sampling causes edge bleed on beveled D6 geometry.
		material.metalness.minificationFilter = .nearest
		material.metalness.magnificationFilter = .nearest
		material.metalness.mipFilter = .none
		material.roughness.minificationFilter = .nearest
		material.roughness.magnificationFilter = .nearest
		material.roughness.mipFilter = .none
		material.locksAmbientWithDiffuse = true
		material.isDoubleSided = false

		if dieFinish == .stone {
			material.emission.contents = DiceFaceContrast.style(for: fillColor).primaryInkColor
			material.emission.intensity = 1.0
		} else {
			material.emission.contents = UIColor.black
			material.emission.intensity = 0.0
		}
		dieFinish.apply(to: material, baseColor: fillColor, dieIndex: dieIndex)
		material.specular.contents = textureSet.metalness
		if dieFinish != .stone {
			material.shininess = max(material.shininess, 0.42)
		}
		return material
	}

	static func makeSolidMaterial(
		baseColor: UIColor,
		fillColor: UIColor,
		dieFinish: DiceDieFinish,
		dieIndex: Int
	) -> SCNMaterial {
		let material = SCNMaterial()
		material.diffuse.contents = baseColor
		material.normal.contents = DiceFaceTextureFactory.flatNormalMap()
		material.normal.intensity = 0.35
		material.specular.contents = UIColor.black
		material.metalness.contents = UIColor.black
		material.roughness.contents = UIColor.black
		material.locksAmbientWithDiffuse = true
		material.isDoubleSided = false
		material.emission.contents = UIColor.black
		material.emission.intensity = 0.0
		dieFinish.apply(to: material, baseColor: fillColor, dieIndex: dieIndex)
		return material
	}

	static func multipliedColor(_ color: UIColor, factor: CGFloat) -> UIColor {
		var red: CGFloat = 0
		var green: CGFloat = 0
		var blue: CGFloat = 0
		var alpha: CGFloat = 0
		if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
			return UIColor(
				red: max(0, min(1, red * factor)),
				green: max(0, min(1, green * factor)),
				blue: max(0, min(1, blue * factor)),
				alpha: alpha
			)
		}
		var white: CGFloat = 0
		if color.getWhite(&white, alpha: &alpha) {
			let adjusted = max(0, min(1, white * factor))
			return UIColor(white: adjusted, alpha: alpha)
		}
		return color
	}
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
