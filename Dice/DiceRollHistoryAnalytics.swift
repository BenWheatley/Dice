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
}
