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

struct DicePool: Equatable {
	let diceCount: Int
	let sideCount: Int
}

struct RollConfiguration {
	let pools: [DicePool]
	let intuitive: Bool

	init(diceCount: Int, sideCount: Int, intuitive: Bool) {
		self.pools = [DicePool(diceCount: diceCount, sideCount: sideCount)]
		self.intuitive = intuitive
	}

	init(pools: [DicePool], intuitive: Bool) {
		self.pools = pools
		self.intuitive = intuitive
	}

	var diceCount: Int {
		pools.reduce(0) { $0 + $1.diceCount }
	}

	var sideCount: Int {
		pools.first?.sideCount ?? 6
	}

	var uniformSideCount: Int? {
		guard let first = pools.first?.sideCount else { return nil }
		return pools.dropFirst().allSatisfy { $0.sideCount == first } ? first : nil
	}

	var sideCountsPerDie: [Int] {
		var result: [Int] = []
		result.reserveCapacity(diceCount)
		for pool in pools {
			result.append(contentsOf: Array(repeating: pool.sideCount, count: pool.diceCount))
		}
		return result
	}

	var notation: String {
		let body = pools.map { "\($0.diceCount)d\($0.sideCount)" }.joined(separator: "+")
		return "\(body)\(intuitive ? "i" : "")"
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
		let sanitized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
		if sanitized.isEmpty { throw DiceInputError.emptyInput }

		let intuitive = sanitized.contains("i")
		let withoutIntuitiveFlag = sanitized.replacingOccurrences(of: "i", with: "")

		let pools: [DicePool]
		if withoutIntuitiveFlag.allSatisfy(\.isNumber) {
			guard let parsedDice = Int(withoutIntuitiveFlag) else {
				throw DiceInputError.invalidFormat
			}
			pools = [DicePool(diceCount: parsedDice, sideCount: 6)]
		} else {
			let tokens = withoutIntuitiveFlag
				.split(whereSeparator: { !$0.isNumber && $0 != "d" })
				.map(String.init)
			guard !tokens.isEmpty else { throw DiceInputError.invalidFormat }

			var parsedPools: [DicePool] = []
			parsedPools.reserveCapacity(tokens.count)
			for token in tokens {
				let components = token.split(separator: "d", omittingEmptySubsequences: false)
				guard components.count == 2 else {
					throw DiceInputError.invalidFormat
				}
				let countPart = String(components[0])
				let sidePart = String(components[1])
				guard !sidePart.isEmpty, sidePart.allSatisfy(\.isNumber) else {
					throw DiceInputError.invalidFormat
				}
				guard countPart.isEmpty || countPart.allSatisfy(\.isNumber) else {
					throw DiceInputError.invalidFormat
				}
				let count = countPart.isEmpty ? 1 : Int(countPart)
				guard let parsedCount = count, let parsedSides = Int(sidePart) else {
					throw DiceInputError.invalidFormat
				}
				parsedPools.append(DicePool(diceCount: parsedCount, sideCount: parsedSides))
			}
			pools = parsedPools
		}

		let totalDice = pools.reduce(0) { $0 + $1.diceCount }
		let validPools = pools.allSatisfy { diceBounds.contains($0.diceCount) && sideBounds.contains($0.sideCount) }
		guard validPools, diceBounds.contains(totalDice) else {
			throw DiceInputError.outOfBounds(diceBounds: diceBounds, sideBounds: sideBounds)
		}

		return RollConfiguration(pools: pools, intuitive: intuitive)
	}
}
