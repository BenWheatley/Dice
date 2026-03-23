import UIKit

enum DiceBoardLayoutCalculator {
	private static let readableReferenceWidth: CGFloat = 390
	private static let readableReferenceColumns: CGFloat = 3

	static func layoutNeedsRefresh(previousBounds: CGRect?, currentBounds: CGRect) -> Bool {
		guard let previousBounds else { return true }
		let widthDelta = abs(previousBounds.width - currentBounds.width)
		let heightDelta = abs(previousBounds.height - currentBounds.height)
		return widthDelta > 0.5 || heightDelta > 0.5
	}

	static func readableBoardSideLengthFloor(layoutPreset: DiceBoardLayoutPreset, mixed: Bool) -> CGFloat {
		let spacingFactor = boardSpacingFactor(layoutPreset: layoutPreset, mixed: mixed)
		return readableReferenceWidth / (readableReferenceColumns + (readableReferenceColumns + 1) * spacingFactor)
	}

	static func boardRenderLayout(
		itemCount: Int,
		bounds: CGRect,
		layoutPreset: DiceBoardLayoutPreset,
		mixed: Bool
	) -> (centers: [CGPoint], sideLength: CGFloat) {
		guard itemCount > 0, bounds.width > 1, bounds.height > 1 else { return ([], 0) }
		let spacingFactor = boardSpacingFactor(layoutPreset: layoutPreset, mixed: mixed)
		let readableFloor = readableBoardSideLengthFloor(layoutPreset: layoutPreset, mixed: mixed)
		let maxColumnsAtReadableFloor = max(
			1,
			Int(
				floor(
					((bounds.width / readableFloor) - spacingFactor) / (1 + spacingFactor)
				)
			)
		)
		let columns = min(itemCount, maxColumnsAtReadableFloor)
		let rows = Int(ceil(Double(itemCount) / Double(columns)))
		let sideByWidth = bounds.width / (CGFloat(columns) + CGFloat(columns + 1) * spacingFactor)
		let maxSideLength = min(bounds.width, bounds.height) * 0.34
		let readableOrWidthBoundFloor = min(readableFloor, sideByWidth)
		let sideLength = max(readableOrWidthBoundFloor, min(sideByWidth, maxSideLength))
		let gap = sideLength * spacingFactor
		let rowCapacity = min(columns, itemCount)
		let totalGridWidth = CGFloat(rowCapacity) * sideLength + CGFloat(max(0, rowCapacity - 1)) * gap
		let totalGridHeight = CGFloat(rows) * sideLength + CGFloat(max(0, rows - 1)) * gap
		let startX = bounds.midX - totalGridWidth / 2 + sideLength / 2
		let startY: CGFloat
		if totalGridHeight <= bounds.height {
			startY = bounds.midY - totalGridHeight / 2 + sideLength / 2
		} else {
			startY = bounds.minY + gap + sideLength / 2
		}

		var centers: [CGPoint] = []
		centers.reserveCapacity(itemCount)
		for index in 0..<itemCount {
			let row = index / columns
			let column = index % columns
			let x = startX + CGFloat(column) * (sideLength + gap)
			let y = startY + CGFloat(row) * (sideLength + gap)
			centers.append(CGPoint(x: x, y: y))
		}
		return (centers, sideLength)
	}

	private static func boardSpacingFactor(layoutPreset: DiceBoardLayoutPreset, mixed: Bool) -> CGFloat {
		switch layoutPreset {
		case .compact:
			return mixed ? 0.16 : 0.13
		case .spacious:
			return mixed ? 0.26 : 0.22
		}
	}
}
