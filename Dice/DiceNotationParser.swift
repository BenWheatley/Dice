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

struct DicePool: Equatable {
	let diceCount: Int
	let sideCount: Int
	let intuitive: Bool
	let colorTag: String?

	init(diceCount: Int, sideCount: Int, intuitive: Bool = false) {
		self.diceCount = diceCount
		self.sideCount = sideCount
		self.intuitive = intuitive
		self.colorTag = nil
	}

	init(diceCount: Int, sideCount: Int, intuitive: Bool, colorTag: String?) {
		self.diceCount = diceCount
		self.sideCount = sideCount
		self.intuitive = intuitive
		self.colorTag = colorTag
	}
}

struct RollConfiguration {
	let pools: [DicePool]

	init(diceCount: Int, sideCount: Int, intuitive: Bool) {
		self.pools = [DicePool(diceCount: diceCount, sideCount: sideCount, intuitive: intuitive)]
	}

	init(pools: [DicePool], intuitive: Bool) {
		self.pools = pools.map { DicePool(diceCount: $0.diceCount, sideCount: $0.sideCount, intuitive: intuitive) }
	}

	init(pools: [DicePool]) {
		self.pools = pools
	}

	var intuitive: Bool {
		pools.allSatisfy(\.intuitive)
	}

	var hasIntuitivePools: Bool {
		pools.contains(where: \.intuitive)
	}

	var hasTrueRandomPools: Bool {
		pools.contains(where: { !$0.intuitive })
	}

	var perDieIntuitiveFlags: [Bool] {
		var flags: [Bool] = []
		flags.reserveCapacity(diceCount)
		for pool in pools {
			flags.append(contentsOf: Array(repeating: pool.intuitive, count: pool.diceCount))
		}
		return flags
	}

	var perDieColorTags: [String?] {
		var tags: [String?] = []
		tags.reserveCapacity(diceCount)
		for pool in pools {
			tags.append(contentsOf: Array(repeating: pool.colorTag, count: pool.diceCount))
		}
		return tags
	}

	var modeSignature: String {
		pools.map { $0.intuitive ? "i" : "r" }.joined(separator: ",")
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
		pools
			.map {
				let color = $0.colorTag.map { "(\($0))" } ?? ""
				return "\($0.diceCount)d\($0.sideCount)\($0.intuitive ? "i" : "")\(color)"
			}
			.joined(separator: "+")
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

		if let invalidCharacter = sanitized.first(where: { !$0.isNumber && !$0.isLetter && $0 != "d" && $0 != "i" && $0 != "+" && $0 != "," && $0 != "&" && $0 != "(" && $0 != ")" && !$0.isWhitespace }) {
			throw DiceInputError.invalidSegment(
				segment: String(invalidCharacter),
				hintKey: "error.input.hint.invalidCharacter"
			)
		}

		let pools: [DicePool]
		if sanitized.allSatisfy(\.isNumber) {
			guard let parsedDice = Int(sanitized) else {
				throw DiceInputError.invalidFormat
			}
			pools = [DicePool(diceCount: parsedDice, sideCount: 6, intuitive: false)]
		} else {
			let tokens = sanitized
				.split(whereSeparator: { $0 == "+" || $0 == "," || $0 == "&" || $0.isWhitespace })
				.map(String.init)
			guard !tokens.isEmpty else { throw DiceInputError.invalidFormat }
			let tokenRegex = try NSRegularExpression(pattern: #"^(\d*)d(\d+)(i)?(?:\(([a-z]+)\))?$"#)
			let supportedColorTags: Set<String> = ["red", "green", "blue", "ivory", "amber", "slate", "crimson", "emerald", "sapphire"]

			var parsedPools: [DicePool] = []
			parsedPools.reserveCapacity(tokens.count)
			for token in tokens {
				let range = NSRange(token.startIndex..<token.endIndex, in: token)
				guard let match = tokenRegex.firstMatch(in: token, options: [], range: range) else {
					if token.hasSuffix("d") {
						throw DiceInputError.invalidSegment(segment: token, hintKey: "error.input.hint.missingSides")
					}
					if !token.contains("d"), let invalid = token.first(where: { !$0.isNumber && $0 != "i" }) {
						throw DiceInputError.invalidSegment(segment: String(invalid), hintKey: "error.input.hint.invalidCharacter")
					}
					throw DiceInputError.invalidSegment(segment: token, hintKey: "error.input.hint.poolShape")
				}

				func capture(_ index: Int) -> String? {
					let captureRange = match.range(at: index)
					guard captureRange.location != NSNotFound,
						  let stringRange = Range(captureRange, in: token) else { return nil }
					return String(token[stringRange])
				}

				let countPart = capture(1) ?? ""
				let sidePart = capture(2) ?? ""
				let intuitive = capture(3) != nil
				let colorTag = capture(4)
				let count = countPart.isEmpty ? 1 : Int(countPart)
				guard let parsedCount = count, let parsedSides = Int(sidePart), !sidePart.isEmpty else {
					throw DiceInputError.invalidFormat
				}
				let parsedColorTag: String?
				if let colorTag {
					guard colorTag.allSatisfy(\.isLetter) else {
						throw DiceInputError.invalidSegment(segment: token, hintKey: "error.input.hint.colorTag")
					}
					let normalized = colorTag.lowercased()
					guard supportedColorTags.contains(normalized) else {
						throw DiceInputError.invalidSegment(segment: token, hintKey: "error.input.hint.colorTag")
					}
					parsedColorTag = normalized
				} else {
					parsedColorTag = nil
				}
				parsedPools.append(DicePool(diceCount: parsedCount, sideCount: parsedSides, intuitive: intuitive, colorTag: parsedColorTag))
			}
			pools = parsedPools
		}

		let totalDice = pools.reduce(0) { $0 + $1.diceCount }
		let validPools = pools.allSatisfy { diceBounds.contains($0.diceCount) && sideBounds.contains($0.sideCount) }
		guard validPools, diceBounds.contains(totalDice) else {
			throw DiceInputError.outOfBounds(diceBounds: diceBounds, sideBounds: sideBounds)
		}

		return RollConfiguration(pools: pools)
	}
}
