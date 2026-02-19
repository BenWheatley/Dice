//
//  DiceRollHistoryAnalytics.swift
//  Dice
//
//  Created by Codex on 19.02.26.
//

import Foundation

struct RollHistogram: Equatable {
	let sideCount: Int
	let bins: [Int]
	let totalSamples: Int
}

struct RollHistoryIndicators: Equatable {
	let highStreak: Int
	let lowStreak: Int
	let outlierNotation: String?
	let outlierZScore: Double?

	var hasHighlights: Bool {
		highStreak >= 3 || lowStreak >= 3 || (outlierZScore.map { abs($0) >= 1.75 } ?? false)
	}
}

enum RollHistoryAnalytics {
	static func histograms(
		entries: [RollHistoryEntry],
		parser: DiceNotationParser = DiceNotationParser(),
		maxEntries: Int = 60
	) -> [RollHistogram] {
		guard maxEntries > 0 else { return [] }
		let recent = Array(entries.prefix(maxEntries))
		guard !recent.isEmpty else { return [] }

		var countsBySides: [Int: [Int]] = [:]
		for entry in recent {
			guard let parsed = parser.parse(entry.notation) else { continue }
			let sideCounts = parsed.sideCountsPerDie
			guard sideCounts.count == entry.values.count else { continue }
			for (value, sides) in zip(entry.values, sideCounts) {
				guard value >= 1, value <= sides else { continue }
				var bins = countsBySides[sides] ?? Array(repeating: 0, count: sides)
				bins[value - 1] += 1
				countsBySides[sides] = bins
			}
		}

		return countsBySides.keys.sorted().compactMap { sides in
			guard let bins = countsBySides[sides] else { return nil }
			return RollHistogram(
				sideCount: sides,
				bins: bins,
				totalSamples: bins.reduce(0, +)
			)
		}
	}

	static func histogramSummaryText(_ histograms: [RollHistogram], topCount: Int = 3) -> String? {
		let nonEmpty = histograms.filter { $0.totalSamples > 0 }
		guard !nonEmpty.isEmpty else { return nil }

		let lines = nonEmpty
			.sorted { lhs, rhs in
				if lhs.totalSamples == rhs.totalSamples {
					return lhs.sideCount < rhs.sideCount
				}
				return lhs.totalSamples > rhs.totalSamples
			}
			.prefix(max(1, topCount))
			.map { histogram in
				let peak = max(1, histogram.bins.max() ?? 1)
				let compact = histogram.bins.enumerated().map { offset, count in
					let bars = max(1, Int(round((Double(count) / Double(peak)) * 6)))
					return "\(offset + 1)\(String(repeating: "▮", count: bars))"
				}.joined(separator: " ")
				return "d\(histogram.sideCount) (\(histogram.totalSamples)): \(compact)"
			}

		return lines.joined(separator: "\n")
	}

	static func indicators(
		entries: [RollHistoryEntry],
		parser: DiceNotationParser = DiceNotationParser(),
		maxEntries: Int = 60
	) -> RollHistoryIndicators {
		guard maxEntries > 0 else {
			return RollHistoryIndicators(highStreak: 0, lowStreak: 0, outlierNotation: nil, outlierZScore: nil)
		}
		let recent = Array(entries.prefix(maxEntries).reversed())
		var longestHigh = 0
		var longestLow = 0
		var currentHigh = 0
		var currentLow = 0
		var outlierNotation: String?
		var outlierZScore: Double?

		for entry in recent {
			guard let parsed = parser.parse(entry.notation) else { continue }
			let sideCounts = parsed.sideCountsPerDie
			guard sideCounts.count == entry.values.count else { continue }

			for (value, sides) in zip(entry.values, sideCounts) where sides >= 2 {
				let highThreshold = Int(ceil(Double(sides) * 0.8))
				let lowThreshold = Int(floor(Double(sides) * 0.2))
				if value >= max(1, highThreshold) {
					currentHigh += 1
					longestHigh = max(longestHigh, currentHigh)
				} else {
					currentHigh = 0
				}
				if value <= max(1, lowThreshold) {
					currentLow += 1
					longestLow = max(longestLow, currentLow)
				} else {
					currentLow = 0
				}
			}

			let pools = parsed.pools
			let expected = pools.reduce(0.0) { partial, pool in
				partial + (Double(pool.diceCount) * (Double(pool.sideCount) + 1.0) / 2.0)
			}
			let variance = pools.reduce(0.0) { partial, pool in
				let side = Double(pool.sideCount)
				return partial + (Double(pool.diceCount) * ((side * side) - 1.0) / 12.0)
			}
			if variance > 0 {
				let zScore = (Double(entry.sum) - expected) / sqrt(variance)
				if outlierZScore == nil || abs(zScore) > abs(outlierZScore ?? 0) {
					outlierZScore = zScore
					outlierNotation = entry.notation
				}
			}
		}

		return RollHistoryIndicators(
			highStreak: longestHigh,
			lowStreak: longestLow,
			outlierNotation: outlierNotation,
			outlierZScore: outlierZScore
		)
	}
}
