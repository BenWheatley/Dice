import UIKit
import SceneKit

struct D6SceneKitRenderConfig {
	struct FaceTextureSet {
		let diffuse: UIImage
		let normal: UIImage
		let metalness: UIImage
		let roughness: UIImage
	}

	static let goldOutlineColor = UIColor(red: 0.84, green: 0.70, blue: 0.28, alpha: 1.0)

	static func beveledCube(sideLength: CGFloat) -> SCNBox {
		let box = SCNBox(
			width: sideLength,
			height: sideLength,
			length: sideLength,
			chamferRadius: sideLength * 0.08
		)
		box.chamferSegmentCount = 4
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
		let size = CGSize(width: 256, height: 256)
		let rect = CGRect(origin: .zero, size: size)
		let style = DiceFaceContrast.style(for: fillColor)

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
				drawPip(
					in: context,
					center: pipPositions[index],
					radius: radius,
					pipStyle: pipStyle,
					fill: nil,
					stroke: UIColor.white,
					lineWidth: 4
				)
			}
		}

		let diffuse = UIGraphicsImageRenderer(size: size).image { _ in
			style.fillColor.setFill()
			UIBezierPath(rect: rect).fill()
			style.borderColor.setStroke()
			let border = UIBezierPath(rect: rect.insetBy(dx: 6, dy: 6))
			border.lineWidth = 8
			border.stroke()

			for index in indexesByValue[value] ?? [] {
				let center = pipPositions[index]
				let path = pipPath(center: center, radius: radius, pipStyle: pipStyle)
				style.primaryInkColor.setFill()
				path.fill()
				goldOutlineColor.setStroke()
				path.lineWidth = 3
				path.stroke()
			}
		}

		let normal = makeNormalMap(fromMask: symbolFillMask, strength: 2.0)
		let metalness = scalarMap(size: size, base: 0.0, fills: [
			(mask: symbolOutlineMask, value: 1.0),
		])
		let roughness = scalarMap(size: size, base: 0.86, fills: [
			(mask: symbolFillMask, value: 0.46),
			(mask: symbolOutlineMask, value: 0.14),
		])

		return FaceTextureSet(diffuse: diffuse, normal: normal, metalness: metalness, roughness: roughness)
	}

	static func makeNormalMap(fromMask maskImage: UIImage, strength: CGFloat = 2.0) -> UIImage {
		guard let maskCG = maskImage.cgImage else { return UIImage() }
		let width = maskCG.width
		let height = maskCG.height
		guard width > 2, height > 2 else { return maskImage }

		let bytesPerPixel = 1
		let bytesPerRow = width * bytesPerPixel
		var maskData = [UInt8](repeating: 0, count: width * height)
		guard let grayscale = CGContext(
			data: &maskData,
			width: width,
			height: height,
			bitsPerComponent: 8,
			bytesPerRow: bytesPerRow,
			space: CGColorSpaceCreateDeviceGray(),
			bitmapInfo: CGImageAlphaInfo.none.rawValue
		) else {
			return UIImage()
		}
		grayscale.draw(maskCG, in: CGRect(x: 0, y: 0, width: width, height: height))

		let normalBytesPerPixel = 4
		let normalBytesPerRow = width * normalBytesPerPixel
		var normalData = [UInt8](repeating: 0, count: width * height * normalBytesPerPixel)

		func sample(_ x: Int, _ y: Int) -> Float {
			let clampedX = max(0, min(width - 1, x))
			let clampedY = max(0, min(height - 1, y))
			let index = clampedY * width + clampedX
			return Float(maskData[index]) / 255.0
		}

		for y in 0..<height {
			for x in 0..<width {
				let left = sample(x - 1, y)
				let right = sample(x + 1, y)
				let up = sample(x, y - 1)
				let down = sample(x, y + 1)
				let dx = (right - left) * Float(strength)
				let dy = (down - up) * Float(strength)
				var nx = -dx
				var ny = -dy
				var nz: Float = 1.0
				let len = max(0.0001, sqrt(nx * nx + ny * ny + nz * nz))
				nx /= len
				ny /= len
				nz /= len

				let pixelIndex = (y * width + x) * normalBytesPerPixel
				normalData[pixelIndex] = UInt8(max(0, min(255, Int((nx * 0.5 + 0.5) * 255.0))))
				normalData[pixelIndex + 1] = UInt8(max(0, min(255, Int((ny * 0.5 + 0.5) * 255.0))))
				normalData[pixelIndex + 2] = UInt8(max(0, min(255, Int((nz * 0.5 + 0.5) * 255.0))))
				normalData[pixelIndex + 3] = 255
			}
		}

		guard let colorContext = CGContext(
			data: &normalData,
			width: width,
			height: height,
			bitsPerComponent: 8,
			bytesPerRow: normalBytesPerRow,
			space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		),
		let normalCG = colorContext.makeImage() else {
			return UIImage()
		}
		return UIImage(cgImage: normalCG)
	}

	static func scalarMap(size: CGSize, base: CGFloat, fills: [(mask: UIImage, value: CGFloat)]) -> UIImage {
		let rect = CGRect(origin: .zero, size: size)
		return UIGraphicsImageRenderer(size: size).image { context in
			UIColor(white: base, alpha: 1.0).setFill()
			context.cgContext.fill(rect)
			for fill in fills {
				guard let mask = fill.mask.cgImage else { continue }
				context.cgContext.saveGState()
				context.cgContext.clip(to: rect, mask: mask)
				UIColor(white: fill.value, alpha: 1.0).setFill()
				context.cgContext.fill(rect)
				context.cgContext.restoreGState()
			}
		}
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
}
