import UIKit

struct HistorySummaryCardRenderer {
	func render(title: String, body: String, footer: String, size: CGSize = CGSize(width: 1080, height: 1080)) -> UIImage {
		let renderer = UIGraphicsImageRenderer(size: size)
		return renderer.image { context in
			let cg = context.cgContext
			UIColor.systemBackground.setFill()
			cg.fill(CGRect(origin: .zero, size: size))

			let panel = CGRect(x: 72, y: 72, width: size.width - 144, height: size.height - 144)
			let panelPath = UIBezierPath(roundedRect: panel, cornerRadius: 36)
			UIColor.secondarySystemBackground.setFill()
			panelPath.fill()

			let titleAttrs: [NSAttributedString.Key: Any] = [
				.font: UIFont.systemFont(ofSize: 58, weight: .bold),
				.foregroundColor: UIColor.label
			]
			let bodyAttrs: [NSAttributedString.Key: Any] = [
				.font: UIFont.monospacedSystemFont(ofSize: 34, weight: .regular),
				.foregroundColor: UIColor.label
			]
			let footerAttrs: [NSAttributedString.Key: Any] = [
				.font: UIFont.systemFont(ofSize: 26, weight: .regular),
				.foregroundColor: UIColor.secondaryLabel
			]
			(title as NSString).draw(in: CGRect(x: panel.minX + 40, y: panel.minY + 44, width: panel.width - 80, height: 80), withAttributes: titleAttrs)
			(body as NSString).draw(in: CGRect(x: panel.minX + 40, y: panel.minY + 140, width: panel.width - 80, height: panel.height - 250), withAttributes: bodyAttrs)
			(footer as NSString).draw(in: CGRect(x: panel.minX + 40, y: panel.maxY - 80, width: panel.width - 80, height: 44), withAttributes: footerAttrs)
		}
	}
}
