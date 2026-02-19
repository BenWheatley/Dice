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

enum RollHistoryModeFilter: Equatable {
	case all
	case trueRandom
	case intuitive
}

enum RollHistoryDateRangeFilter: Equatable {
	case all
	case last24Hours
	case last7Days
	case last30Days
}

struct RollHistoryFilter: Equatable {
	var searchText: String
	var mode: RollHistoryModeFilter
	var dateRange: RollHistoryDateRangeFilter

	static let `default` = RollHistoryFilter(searchText: "", mode: .all, dateRange: .all)
}

struct RollSessionSummary: Equatable {
	let rollCount: Int
	let totalDiceRolled: Int
	let topNotation: String?
	let latestNotation: String?
	let latestSum: Int?
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

	static func filteredEntries(
		entries: [RollHistoryEntry],
		filter: RollHistoryFilter,
		now: Date = Date()
	) -> [RollHistoryEntry] {
		let search = filter.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		let cutoff: Date?
		switch filter.dateRange {
		case .all:
			cutoff = nil
		case .last24Hours:
			cutoff = now.addingTimeInterval(-24 * 60 * 60)
		case .last7Days:
			cutoff = now.addingTimeInterval(-7 * 24 * 60 * 60)
		case .last30Days:
			cutoff = now.addingTimeInterval(-30 * 24 * 60 * 60)
		}

		return entries.filter { entry in
			if let cutoff, entry.timestamp < cutoff {
				return false
			}
			switch filter.mode {
			case .all:
				break
			case .trueRandom:
				if entry.intuitive { return false }
			case .intuitive:
				if !entry.intuitive { return false }
			}
			if search.isEmpty { return true }
			if entry.notation.lowercased().contains(search) { return true }
			if entry.values.map(String.init).joined(separator: ",").contains(search) { return true }
			return "\(entry.sum)".contains(search)
		}
	}

	static func sessionSummary(entries: [RollHistoryEntry]) -> RollSessionSummary {
		guard !entries.isEmpty else {
			return RollSessionSummary(rollCount: 0, totalDiceRolled: 0, topNotation: nil, latestNotation: nil, latestSum: nil)
		}
		let countsByNotation = entries.reduce(into: [String: Int]()) { partial, entry in
			partial[entry.notation, default: 0] += 1
		}
		let topNotation = countsByNotation.max { lhs, rhs in
			if lhs.value == rhs.value { return lhs.key > rhs.key }
			return lhs.value < rhs.value
		}?.key
		let latest = entries.first
		return RollSessionSummary(
			rollCount: entries.count,
			totalDiceRolled: entries.reduce(0) { $0 + $1.values.count },
			topNotation: topNotation,
			latestNotation: latest?.notation,
			latestSum: latest?.sum
		)
	}
}
