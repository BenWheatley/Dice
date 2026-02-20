import UIKit

final class DiceTextureProvider {
	static let shared = DiceTextureProvider()

	private let cache = NSCache<NSString, UIImage>()

	private init() {}

	func backgroundImage(for texture: DiceTableTexture, size: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage {
		let roundedWidth = max(1, Int(size.width.rounded(.up)))
		let roundedHeight = max(1, Int(size.height.rounded(.up)))
		let normalizedScale = max(1, min(scale, 3))
		let cacheKey = "\(texture.rawValue)@\(roundedWidth)x\(roundedHeight)@\(normalizedScale)" as NSString
		if let cached = cache.object(forKey: cacheKey) {
			return cached
		}
		let image = makeTextureImage(texture, size: CGSize(width: roundedWidth, height: roundedHeight), scale: normalizedScale)
		cache.setObject(image, forKey: cacheKey)
		return image
	}

	private func makeTextureImage(_ texture: DiceTableTexture, size: CGSize, scale: CGFloat) -> UIImage {
		switch texture {
		case .felt:
			return render(size: size, scale: scale, background: UIColor(red: 0.15, green: 0.36, blue: 0.22, alpha: 1.0)) { context in
				let width = Int(size.width)
				let height = Int(size.height)
				for y in 0..<height {
					let lineIntensity = 0.9 + 0.1 * sin(CGFloat(y) * 0.06)
					let fiberColor = UIColor(
						red: 0.08,
						green: 0.26,
						blue: 0.16,
						alpha: 0.22 * lineIntensity
					)
					context.setStrokeColor(fiberColor.cgColor)
					context.setLineWidth(1)
					context.move(to: CGPoint(x: 0, y: CGFloat(y)))
					context.addLine(to: CGPoint(x: CGFloat(width), y: CGFloat(y) + 2.5))
					context.strokePath()
				}

				for x in stride(from: 0, to: width, by: 3) {
					for y in stride(from: 0, to: height, by: 3) {
						let hash = sin(CGFloat((x * 73) ^ (y * 127)) * 0.0137)
						let alpha = 0.02 + ((hash + 1) * 0.5 * 0.035)
						context.setFillColor(UIColor(white: 1, alpha: alpha).cgColor)
						context.fill(CGRect(x: x, y: y, width: 1, height: 1))
					}
				}
			}
		case .wood:
			return render(size: size, scale: scale, background: UIColor(red: 0.49, green: 0.31, blue: 0.18, alpha: 1.0)) { context in
				let width = Int(size.width)
				let height = Int(size.height)
				for y in 0..<height {
					let ny = CGFloat(y) / max(1, size.height)
					let band = sin((ny * 42.0) + (sin(ny * 11.0) * 1.2))
					let grain = sin((ny * 180.0) + (sin(ny * 23.0) * 3.5))
					let tone = 0.42 + (band * 0.06) + (grain * 0.015)
					let color = UIColor(
						red: tone + 0.12,
						green: tone * 0.70,
						blue: tone * 0.44,
						alpha: 1.0
					)
					context.setStrokeColor(color.cgColor)
					context.setLineWidth(1)
					context.move(to: CGPoint(x: 0, y: y))
					context.addLine(to: CGPoint(x: width, y: y))
					context.strokePath()
				}

				context.setStrokeColor(UIColor(red: 0.28, green: 0.17, blue: 0.09, alpha: 0.24).cgColor)
				context.setLineWidth(1.5)
				for y in stride(from: 8, through: height - 8, by: 18) {
					let yy = CGFloat(y)
					context.move(to: CGPoint(x: 0, y: yy))
					context.addCurve(
						to: CGPoint(x: CGFloat(width), y: yy),
						control1: CGPoint(x: size.width * 0.28, y: yy + 6),
						control2: CGPoint(x: size.width * 0.72, y: yy - 6)
					)
					context.strokePath()
				}
			}
		case .neutral:
			if let stripes = UIImage(named: "stripes") {
				return render(size: size, scale: scale, background: UIColor(white: 0.94, alpha: 1.0)) { context in
					let tileSize = CGSize(width: 48, height: 48)
					for y in stride(from: CGFloat(0), to: size.height + tileSize.height, by: tileSize.height) {
						for x in stride(from: CGFloat(0), to: size.width + tileSize.width, by: tileSize.width) {
							stripes.draw(in: CGRect(origin: CGPoint(x: x, y: y), size: tileSize))
						}
					}
				}
			}
			return render(size: size, scale: scale, background: UIColor(white: 0.93, alpha: 1.0)) { context in
				context.setFillColor(UIColor(white: 0.88, alpha: 1.0).cgColor)
				for y in stride(from: CGFloat(0), through: size.height, by: 4) {
					context.fill(CGRect(x: 0, y: y, width: size.width, height: 2))
				}
			}
		}
	}

	private func render(size: CGSize, scale: CGFloat, background: UIColor, draw: (CGContext) -> Void) -> UIImage {
		let format = UIGraphicsImageRendererFormat.default()
		format.scale = scale
		format.opaque = true
		let renderer = UIGraphicsImageRenderer(size: size, format: format)
		return renderer.image { context in
			background.setFill()
			context.fill(CGRect(origin: .zero, size: size))
			draw(context.cgContext)
		}
	}
}
