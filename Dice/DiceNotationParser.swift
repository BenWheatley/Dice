//
//  DiceNotationParser.swift
//  Dice
//
//  Created by Codex on 16.02.26.
//

import Foundation

enum DiceInputError: Error, Equatable {
	case emptyInput
	case invalidFormat
	case outOfBounds(diceBounds: ClosedRange<Int>, sideBounds: ClosedRange<Int>)

	var userMessage: String {
		switch self {
		case .emptyInput:
			return NSLocalizedString("error.input.empty", comment: "Prompt for empty notation input")
		case .invalidFormat:
			return NSLocalizedString("error.input.invalidFormat", comment: "Prompt for invalid notation format")
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

struct RollConfiguration {
	let diceCount: Int
	let sideCount: Int
	let intuitive: Bool

	var notation: String {
		"\(diceCount)d\(sideCount)\(intuitive ? "i" : "")"
	}
}

struct DiceNotationParser {
	let diceBounds: ClosedRange<Int>
	let sideBounds: ClosedRange<Int>

	init(diceBounds: ClosedRange<Int> = 1...30, sideBounds: ClosedRange<Int> = 2...100) {
		self.diceBounds = diceBounds
		self.sideBounds = sideBounds
	}

	func parse(_ text: String) -> RollConfiguration? {
		try? parseOrThrow(text)
	}

	func parseResult(_ text: String) -> Result<RollConfiguration, DiceInputError> {
		Result { try parseOrThrow(text) }.mapError { error in
			(error as? DiceInputError) ?? .invalidFormat
		}
	}

	private func parseOrThrow(_ text: String) throws -> RollConfiguration {
		let sanitized = text.lowercased().replacingOccurrences(of: " ", with: "")
		if sanitized.isEmpty { throw DiceInputError.emptyInput }

		let intuitive = sanitized.contains("i")
		let withoutIntuitiveFlag = sanitized.replacingOccurrences(of: "i", with: "")

		let diceCount: Int
		let sideCount: Int

		if let dIndex = withoutIntuitiveFlag.firstIndex(of: "d") {
			let dicePart = String(withoutIntuitiveFlag[..<dIndex])
			let sidePart = String(withoutIntuitiveFlag[withoutIntuitiveFlag.index(after: dIndex)...])
			guard let parsedDice = Int(dicePart), let parsedSides = Int(sidePart) else {
				throw DiceInputError.invalidFormat
			}
			diceCount = parsedDice
			sideCount = parsedSides
		} else {
			guard let parsedDice = Int(withoutIntuitiveFlag) else { throw DiceInputError.invalidFormat }
			diceCount = parsedDice
			sideCount = 6
		}

		guard diceBounds.contains(diceCount), sideBounds.contains(sideCount) else {
			throw DiceInputError.outOfBounds(diceBounds: diceBounds, sideBounds: sideBounds)
		}

		return RollConfiguration(diceCount: diceCount, sideCount: sideCount, intuitive: intuitive)
	}
}
