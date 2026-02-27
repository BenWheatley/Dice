import CoreGraphics

struct DiceFaceLabelSizing {
	static func textureNumeralPointSize(sideCount: Int, large: Bool) -> CGFloat {
		let base: CGFloat = sideCount == 4 ? 54 : 73
		// Requested UX tuning: double numeral size across die faces for stronger legibility.
		return scaled(base * 2.0, large: large, multiplier: 1.18)
	}

	static func textureCaptionPointSize(large: Bool) -> CGFloat {
		scaled(15, large: large, multiplier: 1.15)
	}

	static func badgeNumeralScale(large: Bool) -> CGFloat {
		large ? 0.62 : 0.56
	}

	static func staticFallbackPointSize(cellSideLength: CGFloat, large: Bool) -> CGFloat {
		let base = min(52, max(26, cellSideLength * 0.42))
		return scaled(base, large: large, multiplier: 1.18)
	}

	private static func scaled(_ value: CGFloat, large: Bool, multiplier: CGFloat) -> CGFloat {
		large ? value * multiplier : value
	}
}
