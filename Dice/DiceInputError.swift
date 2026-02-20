import Foundation

enum DiceInputError: Error, Equatable {
	case emptyInput
	case invalidFormat
	case invalidSegment(segment: String, hintKey: String)
	case outOfBounds(diceBounds: ClosedRange<Int>, sideBounds: ClosedRange<Int>)

	var userMessage: String {
		switch self {
		case .emptyInput:
			return NSLocalizedString("error.input.empty", comment: "Prompt for empty notation input")
		case .invalidFormat:
			return NSLocalizedString("error.input.invalidFormat", comment: "Prompt for invalid notation format")
		case let .invalidSegment(segment, hintKey):
			let hint = NSLocalizedString(hintKey, comment: "Notation parser hint detail")
			return String(
				format: NSLocalizedString("error.input.invalidSegment", comment: "Prompt for segment-specific parser error"),
				locale: .current,
				segment,
				hint
			)
		case let .outOfBounds(diceBounds, sideBounds):
			return String(
				format: NSLocalizedString("error.input.outOfBounds", comment: "Prompt for notation bounds violation"),
				locale: .current,
				diceBounds.lowerBound,
				diceBounds.upperBound,
				sideBounds.lowerBound,
				sideBounds.upperBound
			)
		}
	}
}
