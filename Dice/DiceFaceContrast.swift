import UIKit

enum DiceFaceContrast {
	static func style(for fillColor: UIColor) -> FaceContrastStyle {
		let candidates: [UIColor] = [
			.black,
			.white,
			UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0),
			UIColor(red: 0.92, green: 0.92, blue: 0.94, alpha: 1.0),
		]
		let bestInk = candidates.max { contrastRatio($0, fillColor) < contrastRatio($1, fillColor) } ?? .black
		let lighterBorder = adjustBrightness(fillColor, delta: 0.24)
		let darkerBorder = adjustBrightness(fillColor, delta: -0.24)
		let borderColor = contrastRatio(lighterBorder, fillColor) > contrastRatio(darkerBorder, fillColor) ? lighterBorder : darkerBorder
		let secondaryInk = bestInk.withAlphaComponent(0.72)
		return FaceContrastStyle(
			fillColor: fillColor,
			borderColor: borderColor,
			primaryInkColor: bestInk,
			secondaryInkColor: secondaryInk
		)
	}

	static func contrastRatio(_ lhs: UIColor, _ rhs: UIColor) -> CGFloat {
		let l1 = relativeLuminance(lhs)
		let l2 = relativeLuminance(rhs)
		let lighter = max(l1, l2)
		let darker = min(l1, l2)
		return (lighter + 0.05) / (darker + 0.05)
	}

	private static func relativeLuminance(_ color: UIColor) -> CGFloat {
		var red: CGFloat = 0
		var green: CGFloat = 0
		var blue: CGFloat = 0
		var alpha: CGFloat = 0
		color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
		func transform(_ component: CGFloat) -> CGFloat {
			if component <= 0.03928 {
				return component / 12.92
			}
			return pow((component + 0.055) / 1.055, 2.4)
		}
		let r = transform(red)
		let g = transform(green)
		let b = transform(blue)
		return 0.2126 * r + 0.7152 * g + 0.0722 * b
	}

	private static func adjustBrightness(_ color: UIColor, delta: CGFloat) -> UIColor {
		var red: CGFloat = 0
		var green: CGFloat = 0
		var blue: CGFloat = 0
		var alpha: CGFloat = 0
		color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
		return UIColor(
			red: max(0, min(1, red + delta)),
			green: max(0, min(1, green + delta)),
			blue: max(0, min(1, blue + delta)),
			alpha: alpha
		)
	}
}
