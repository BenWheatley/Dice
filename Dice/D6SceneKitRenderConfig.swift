import UIKit
import SceneKit

struct D6SceneKitRenderConfig {
	private static let textureEdgeLength: CGFloat = 256
	private struct FaceTextureCacheKey: Hashable {
		let value: Int
		let pipStyle: DiceD6PipStyle
		let fillRed: UInt8
		let fillGreen: UInt8
		let fillBlue: UInt8
		let fillAlpha: UInt8
	}

	struct FaceTextureSet {
		let diffuse: UIImage
		let normal: UIImage
		let metalness: UIImage
		let roughness: UIImage
	}

	private static var faceTextureSetCache: [FaceTextureCacheKey: FaceTextureSet] = [:]
	private static let faceTextureSetCacheLock = NSLock()
	private static let flatNormalTexture: UIImage = {
		let size = CGSize(width: 1, height: 1)
		return UIGraphicsImageRenderer(size: size).image { _ in
			UIColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 1.0).setFill()
			UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
		}
	}()

	static func flatNormalMapImage() -> UIImage {
		flatNormalTexture
	}

	static func beveledCube(sideLength: CGFloat) -> SCNBox {
		let box = D6BeveledCubeGeometry.make(sideLength: sideLength)
		box.materials = (1...6).map { faceMaterial(value: $0) }
		return box
	}

	static func faceMaterial(value: Int, fillColor: UIColor = UIColor(white: 0.96, alpha: 1.0), pipStyle: DiceD6PipStyle = .round) -> SCNMaterial {
		let textureSet = faceTextureSet(value: value, fillColor: fillColor, pipStyle: pipStyle)
		let material = SCNMaterial()
		material.diffuse.contents = textureSet.diffuse
		material.normal.contents = textureSet.normal
		material.normal.intensity = 0.95
		material.specular.contents = textureSet.metalness
		material.metalness.contents = textureSet.metalness
		material.roughness.contents = textureSet.roughness
		material.locksAmbientWithDiffuse = true
		material.isDoubleSided = false
		material.shininess = 0.45
		return material
	}

	static func faceTexture(value: Int, fillColor: UIColor = UIColor(white: 0.96, alpha: 1.0), pipStyle: DiceD6PipStyle = .round) -> UIImage {
		faceTextureSet(value: value, fillColor: fillColor, pipStyle: pipStyle).diffuse
	}

	static func faceTextureSet(value: Int, fillColor: UIColor = UIColor(white: 0.96, alpha: 1.0), pipStyle: DiceD6PipStyle = .round) -> FaceTextureSet {
		let key = cacheKey(value: value, fillColor: fillColor, pipStyle: pipStyle)
		faceTextureSetCacheLock.lock()
		if let cached = faceTextureSetCache[key] {
			faceTextureSetCacheLock.unlock()
			return cached
		}
		faceTextureSetCacheLock.unlock()

		let size = CGSize(width: textureEdgeLength, height: textureEdgeLength)
		let rect = CGRect(origin: .zero, size: size)
		let style = DiceFaceContrast.style(for: fillColor)
		let outlineColor = oppositeInkColor(for: style.primaryInkColor)

		let pipPositions: [CGPoint] = [
			CGPoint(x: size.width * 0.28, y: size.height * 0.28),
			CGPoint(x: size.width * 0.50, y: size.height * 0.28),
			CGPoint(x: size.width * 0.72, y: size.height * 0.28),
			CGPoint(x: size.width * 0.28, y: size.height * 0.50),
			CGPoint(x: size.width * 0.50, y: size.height * 0.50),
			CGPoint(x: size.width * 0.72, y: size.height * 0.50),
			CGPoint(x: size.width * 0.28, y: size.height * 0.72),
			CGPoint(x: size.width * 0.50, y: size.height * 0.72),
			CGPoint(x: size.width * 0.72, y: size.height * 0.72),
		]

		let indexesByValue: [Int: [Int]] = [
			1: [4],
			2: [0, 8],
			3: [0, 4, 8],
			4: [0, 2, 6, 8],
			5: [0, 2, 4, 6, 8],
			6: [0, 2, 3, 5, 6, 8],
		]

		let radius = size.width * 0.08
		let pipOutlineWidth = radius * 0.10
		let symbolFillMask = renderMask(size: size) { context in
			for index in indexesByValue[value] ?? [] {
				drawPip(
					in: context,
					center: pipPositions[index],
					radius: radius,
					pipStyle: pipStyle,
					fill: UIColor.white,
					stroke: nil,
					lineWidth: 0
				)
			}
		}
		let symbolOutlineMask = renderMask(size: size) { context in
			for index in indexesByValue[value] ?? [] {
				drawPipOutlineRing(
					in: context,
					center: pipPositions[index],
					radius: radius,
					pipStyle: pipStyle,
					ringWidth: pipOutlineWidth,
					fill: UIColor.white
				)
			}
		}

		let diffuse = UIGraphicsImageRenderer(size: size).image { _ in
			style.fillColor.setFill()
			UIBezierPath(rect: rect).fill()

			for index in indexesByValue[value] ?? [] {
				let center = pipPositions[index]
				let path = pipPath(center: center, radius: radius, pipStyle: pipStyle)
				style.primaryInkColor.setFill()
				path.fill()
				drawPipOutlineRing(
					in: UIGraphicsGetCurrentContext(),
					center: center,
					radius: radius,
					pipStyle: pipStyle,
					ringWidth: pipOutlineWidth,
					fill: outlineColor
				)
			}
		}

		let normal = flatNormalTexture
		// Roughness/metalness channels carry symbol masks. Final PBR response is shader-driven.
		let metalness = symbolOutlineMask
		let roughness = symbolFillMask

		let textureSet = FaceTextureSet(diffuse: diffuse, normal: normal, metalness: metalness, roughness: roughness)
		faceTextureSetCacheLock.lock()
		faceTextureSetCache[key] = textureSet
		faceTextureSetCacheLock.unlock()
		return textureSet
	}

	private static func cacheKey(value: Int, fillColor: UIColor, pipStyle: DiceD6PipStyle) -> FaceTextureCacheKey {
		let rgba = colorComponents(fillColor)
		return FaceTextureCacheKey(
			value: value,
			pipStyle: pipStyle,
			fillRed: rgba.r,
			fillGreen: rgba.g,
			fillBlue: rgba.b,
			fillAlpha: rgba.a
		)
	}

	private static func colorComponents(_ color: UIColor) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
		var r: CGFloat = 0
		var g: CGFloat = 0
		var b: CGFloat = 0
		var a: CGFloat = 0
		if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
			return (
				r: UInt8((r * 255).rounded()),
				g: UInt8((g * 255).rounded()),
				b: UInt8((b * 255).rounded()),
				a: UInt8((a * 255).rounded())
			)
		}

		var white: CGFloat = 0
		if color.getWhite(&white, alpha: &a) {
			let channel = UInt8((white * 255).rounded())
			return (r: channel, g: channel, b: channel, a: UInt8((a * 255).rounded()))
		}
		return (r: 245, g: 245, b: 245, a: 255)
	}

	private static func renderMask(size: CGSize, draw: (CGContext) -> Void) -> UIImage {
		let rect = CGRect(origin: .zero, size: size)
		let renderer = UIGraphicsImageRenderer(size: size)
		return renderer.image { context in
			UIColor.black.setFill()
			context.cgContext.fill(rect)
			draw(context.cgContext)
		}
	}

	private static func pipPath(center: CGPoint, radius: CGFloat, pipStyle: DiceD6PipStyle) -> UIBezierPath {
		let pipRect = CGRect(
			x: center.x - radius,
			y: center.y - radius,
			width: radius * 2,
			height: radius * 2
		)
		switch pipStyle {
		case .round:
			return UIBezierPath(ovalIn: pipRect)
		case .square:
			return UIBezierPath(rect: pipRect.insetBy(dx: radius * 0.08, dy: radius * 0.08))
		}
	}

	private static func drawPip(
		in context: CGContext,
		center: CGPoint,
		radius: CGFloat,
		pipStyle: DiceD6PipStyle,
		fill: UIColor?,
		stroke: UIColor?,
		lineWidth: CGFloat
	) {
		let path = pipPath(center: center, radius: radius, pipStyle: pipStyle)
		if let fill {
			context.setFillColor(fill.cgColor)
			context.addPath(path.cgPath)
			context.fillPath()
		}
		if let stroke, lineWidth > 0 {
			context.setStrokeColor(stroke.cgColor)
			context.setLineWidth(lineWidth)
			context.addPath(path.cgPath)
			context.strokePath()
		}
	}

	private static func drawPipOutlineRing(
		in context: CGContext?,
		center: CGPoint,
		radius: CGFloat,
		pipStyle: DiceD6PipStyle,
		ringWidth: CGFloat,
		fill: UIColor
	) {
		guard let context else { return }
		let outerPath = pipPath(center: center, radius: radius + ringWidth, pipStyle: pipStyle)
		let innerPath = pipPath(center: center, radius: radius, pipStyle: pipStyle)
		outerPath.append(innerPath.reversing())
		outerPath.usesEvenOddFillRule = true
		context.saveGState()
		fill.setFill()
		outerPath.fill()
		context.restoreGState()
	}

	private static func oppositeInkColor(for inkColor: UIColor) -> UIColor {
		let luminance = inkColor.diceRelativeLuminance
		return luminance >= 0.5 ? .black : .white
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
