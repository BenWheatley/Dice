import UIKit

enum DiceTableTexture: String, CaseIterable {
	case felt
	case wood
	case neutral

	var menuTitleKey: String {
		switch self {
		case .felt:
			return "texture.felt"
		case .wood:
			return "texture.wood"
		case .neutral:
			return "texture.neutral"
		}
	}
}

final class DiceTextureProvider {
	static let shared = DiceTextureProvider()

	private let cache = NSCache<NSString, UIImage>()

	private init() {}

	func patternColor(for texture: DiceTableTexture) -> UIColor {
		let cacheKey = "\(texture.rawValue)@\(UIScreen.main.scale)" as NSString
		if let cached = cache.object(forKey: cacheKey) {
			return UIColor(patternImage: cached)
		}
		let image = makeTextureImage(texture)
		cache.setObject(image, forKey: cacheKey)
		return UIColor(patternImage: image)
	}

	private func makeTextureImage(_ texture: DiceTableTexture) -> UIImage {
		switch texture {
		case .felt:
			return render(size: CGSize(width: 64, height: 64), background: UIColor(red: 0.16, green: 0.38, blue: 0.22, alpha: 1.0)) { context in
				context.setLineWidth(1)
				context.setStrokeColor(UIColor(red: 0.10, green: 0.30, blue: 0.17, alpha: 0.55).cgColor)
				for y in stride(from: 0, through: 64, by: 6) {
					context.move(to: CGPoint(x: 0, y: y))
					context.addLine(to: CGPoint(x: 64, y: y + 4))
				}
				context.strokePath()
			}
		case .wood:
			return render(size: CGSize(width: 72, height: 72), background: UIColor(red: 0.48, green: 0.31, blue: 0.18, alpha: 1.0)) { context in
				context.setLineWidth(2)
				for (index, y) in stride(from: 4, through: 70, by: 8).enumerated() {
					let jitter = CGFloat(index % 3) * 1.3
					let yPosition = CGFloat(y)
					context.setStrokeColor(UIColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 0.45).cgColor)
					context.move(to: CGPoint(x: 0, y: yPosition + jitter))
					context.addCurve(to: CGPoint(x: 72, y: yPosition - jitter), control1: CGPoint(x: 24, y: yPosition + 4), control2: CGPoint(x: 48, y: yPosition - 4))
					context.strokePath()
				}
			}
		case .neutral:
			if let image = UIImage(named: "stripes") {
				return image
			}
			return render(size: CGSize(width: 48, height: 48), background: UIColor(white: 0.93, alpha: 1.0)) { context in
				context.setFillColor(UIColor(white: 0.88, alpha: 1.0).cgColor)
				for y in stride(from: 0, through: 48, by: 4) {
					context.fill(CGRect(x: 0, y: y, width: 48, height: 2))
				}
			}
		}
	}

	private func render(size: CGSize, background: UIColor, draw: (CGContext) -> Void) -> UIImage {
		let renderer = UIGraphicsImageRenderer(size: size)
		return renderer.image { context in
			background.setFill()
			context.fill(CGRect(origin: .zero, size: size))
			draw(context.cgContext)
		}
	}
}
