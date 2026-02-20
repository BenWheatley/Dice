import UIKit
import SceneKit

struct D6SceneKitRenderConfig {
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
		let material = SCNMaterial()
		material.diffuse.contents = faceTexture(value: value, fillColor: fillColor, pipStyle: pipStyle)
		material.locksAmbientWithDiffuse = true
		material.isDoubleSided = false
		return material
	}

	static func faceTexture(value: Int, fillColor: UIColor = UIColor(white: 0.96, alpha: 1.0), pipStyle: DiceD6PipStyle = .round) -> UIImage {
		let size = CGSize(width: 256, height: 256)
		let width = Int(size.width)
		let height = Int(size.height)
		guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
			  let context = CGContext(
				data: nil,
				width: width,
				height: height,
				bitsPerComponent: 8,
				bytesPerRow: 0,
				space: colorSpace,
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
			  ) else {
			return UIImage()
		}

		let rect = CGRect(origin: .zero, size: size)
		let style = DiceFaceContrast.style(for: fillColor)
		context.setFillColor(style.fillColor.cgColor)
		context.fill(rect)
		context.setStrokeColor(style.borderColor.cgColor)
		context.setLineWidth(8)
		context.stroke(rect.insetBy(dx: 6, dy: 6))

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
		for index in indexesByValue[value] ?? [] {
			let center = pipPositions[index]
			let pipRect = CGRect(
				x: center.x - radius,
				y: center.y - radius,
				width: radius * 2,
				height: radius * 2
			)
			switch pipStyle {
			case .round:
				context.setFillColor(style.primaryInkColor.cgColor)
				context.fillEllipse(in: pipRect)
			case .square:
				context.setFillColor(style.primaryInkColor.cgColor)
				context.fill(pipRect.insetBy(dx: radius * 0.08, dy: radius * 0.08))
			case .inset:
				context.setFillColor(style.borderColor.cgColor)
				context.fillEllipse(in: pipRect)
				let inner = pipRect.insetBy(dx: radius * 0.42, dy: radius * 0.42)
				context.setFillColor(style.primaryInkColor.cgColor)
				context.fillEllipse(in: inner)
			}
		}

		guard let image = context.makeImage() else { return UIImage() }
		return UIImage(cgImage: image)
	}
}
