import UIKit

enum DiceFaceNumeralFont: String, CaseIterable {
	case classic
	case serif
	case rounded
	case mono
	case dyslexiaFriendly

	var menuTitleKey: String {
		switch self {
		case .classic:
			return "font.classic"
		case .serif:
			return "font.serif"
		case .rounded:
			return "font.rounded"
		case .mono:
			return "font.mono"
		case .dyslexiaFriendly:
			return "font.dyslexiaFriendly"
		}
	}

	func numeralFont(ofSize size: CGFloat) -> UIFont {
		let base = UIFont.systemFont(ofSize: size, weight: .bold)
		switch self {
		case .classic:
			return base
		case .serif:
			guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
			return UIFont(descriptor: descriptor, size: size)
		case .rounded:
			guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
			return UIFont(descriptor: descriptor, size: size)
		case .mono:
			guard let descriptor = base.fontDescriptor.withDesign(.monospaced) else { return base }
			return UIFont(descriptor: descriptor, size: size)
		case .dyslexiaFriendly:
			return UIFont(name: "OpenDyslexic3-Regular", size: size)
				?? UIFont(name: "OpenDyslexic-Regular", size: size)
				?? UIFont(name: "AtkinsonHyperlegible-Bold", size: size)
				?? UIFont.systemFont(ofSize: size, weight: .semibold)
		}
	}

	func captionFont(ofSize size: CGFloat) -> UIFont {
		switch self {
		case .mono:
			return UIFont.monospacedSystemFont(ofSize: size, weight: .medium)
		case .dyslexiaFriendly:
			return UIFont(name: "AtkinsonHyperlegible-Regular", size: size)
				?? UIFont.systemFont(ofSize: size, weight: .regular)
		default:
			return UIFont.systemFont(ofSize: size, weight: .medium)
		}
	}

	func isReadable(sampleText: String, pointSize: CGFloat, canvas: CGSize, inset: CGFloat) -> Bool {
		let attributes: [NSAttributedString.Key: Any] = [.font: numeralFont(ofSize: pointSize)]
		let bounds = (sampleText as NSString).size(withAttributes: attributes)
		let maxWidth = canvas.width - inset * 2
		let maxHeight = canvas.height - inset * 2
		return bounds.width <= maxWidth && bounds.height <= maxHeight
	}
}
