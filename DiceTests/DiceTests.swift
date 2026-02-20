//
//  DiceTests.swift
//  DiceTests
//
//  Created by Ben Wheatley on 2018/09/27.
//  Copyright © 2018 Ben Wheatley. All rights reserved.
//

import XCTest
import UIKit
import SceneKit
import simd
@testable import Dice

final class DiceTests: XCTestCase {
	private let parser = DiceNotationParser()

	func testParseStandardNotation() {
		let configuration = parser.parse("6d8")
		XCTAssertNotNil(configuration)
		XCTAssertEqual(configuration?.diceCount, 6)
		XCTAssertEqual(configuration?.sideCount, 8)
		XCTAssertEqual(configuration?.intuitive, false)
	}

	func testParseSingleNumberDefaultsToD6() {
		let configuration = parser.parse("20")
		XCTAssertNotNil(configuration)
		XCTAssertEqual(configuration?.diceCount, 20)
		XCTAssertEqual(configuration?.sideCount, 6)
		XCTAssertEqual(configuration?.intuitive, false)
	}

	func testParseIntuitiveSuffix() {
		let configuration = parser.parse("6d6i")
		XCTAssertNotNil(configuration)
		XCTAssertEqual(configuration?.diceCount, 6)
		XCTAssertEqual(configuration?.sideCount, 6)
		XCTAssertEqual(configuration?.intuitive, true)
	}

	func testParseSupportsPerPoolIntuitiveFlags() {
		let configuration = parser.parse("d20i d20")
		XCTAssertNotNil(configuration)
		XCTAssertEqual(configuration?.diceCount, 2)
		XCTAssertEqual(configuration?.pools, [
			DicePool(diceCount: 1, sideCount: 20, intuitive: true),
			DicePool(diceCount: 1, sideCount: 20, intuitive: false),
		])
		XCTAssertEqual(configuration?.notation, "1d20i+1d20")
	}

	func testParseIsCaseInsensitiveAndTrimsSpaces() {
		let configuration = parser.parse("  5D10I  ")
		XCTAssertNotNil(configuration)
		XCTAssertEqual(configuration?.diceCount, 5)
		XCTAssertEqual(configuration?.sideCount, 10)
		XCTAssertEqual(configuration?.intuitive, true)
	}

	func testParseRejectsMalformedInput() {
		XCTAssertNil(parser.parse(""))
		XCTAssertNil(parser.parse("abc"))
		XCTAssertNotNil(parser.parse("d6"))
		XCTAssertNil(parser.parse("6d"))
	}

	func testParseSupportsMixedDiceWithCommonSeparatorsAndImplicitOne() {
		let mixedSpace = parser.parse("3d6 2d4 d20")
		XCTAssertEqual(mixedSpace?.diceCount, 6)
		XCTAssertEqual(mixedSpace?.pools, [
			DicePool(diceCount: 3, sideCount: 6),
			DicePool(diceCount: 2, sideCount: 4),
			DicePool(diceCount: 1, sideCount: 20)
		])
		XCTAssertNil(mixedSpace?.uniformSideCount)

		let mixedPlus = parser.parse("3d20+1d6")
		XCTAssertEqual(mixedPlus?.pools, [
			DicePool(diceCount: 3, sideCount: 20),
			DicePool(diceCount: 1, sideCount: 6)
		])

		let mixedComma = parser.parse("3d20, 1d6")
		XCTAssertEqual(mixedComma?.pools, [
			DicePool(diceCount: 3, sideCount: 20),
			DicePool(diceCount: 1, sideCount: 6)
		])

		let mixedAmp = parser.parse("3d20 & 1d6")
		XCTAssertEqual(mixedAmp?.pools, [
			DicePool(diceCount: 3, sideCount: 20),
			DicePool(diceCount: 1, sideCount: 6)
		])
	}

	func testParsePropertyBasedMixedSeparatorsAndWhitespace() {
		var state: UInt64 = 0xD1CE_2026
		func nextInt(_ upperBound: Int) -> Int {
			state = state &* 6364136223846793005 &+ 1442695040888963407
			return Int(state % UInt64(upperBound))
		}

		let separators = ["+", " + ", " ", "  ", ",", ", ", " & ", "&"]
		for _ in 0..<200 {
			let poolCount = 2 + nextInt(3) // 2...4 pools
			var expectedPools: [DicePool] = []
			var terms: [String] = []
			for _ in 0..<poolCount {
				let diceCount = 1 + nextInt(6)
				let sideCount = [4, 6, 8, 10, 12, 20][nextInt(6)]
				expectedPools.append(DicePool(diceCount: diceCount, sideCount: sideCount))
				let useImplicitOne = diceCount == 1 && nextInt(2) == 0
				let dToken = nextInt(2) == 0 ? "d" : "D"
				let term = useImplicitOne ? "\(dToken)\(sideCount)" : "\(diceCount)\(dToken)\(sideCount)"
				terms.append(term)
			}

			var notation = terms[0]
			for index in 1..<terms.count {
				notation += separators[nextInt(separators.count)] + terms[index]
			}
			if nextInt(2) == 0 { notation = "  " + notation }
			if nextInt(2) == 0 { notation += "   " }

			let parsed = parser.parse(notation)
			XCTAssertNotNil(parsed, "Expected parse success for notation: \(notation)")
			XCTAssertEqual(parsed?.pools, expectedPools, "Unexpected pools for notation: \(notation)")
		}
	}

	func testParseResultReturnsStructuredErrors() {
		if case let .failure(error) = parser.parseResult("") {
			XCTAssertEqual(error, .emptyInput)
		} else {
			XCTFail("Expected empty input failure")
		}

		if case let .failure(error) = parser.parseResult("31d6") {
			XCTAssertEqual(error, .outOfBounds(diceBounds: 1...30, sideBounds: 2...100))
		} else {
			XCTFail("Expected out-of-bounds failure")
		}
	}

	func testParseResultInvalidSegmentHintsForMalformedGroups() {
		if case let .failure(error) = parser.parseResult("3x6") {
			XCTAssertEqual(error, .invalidSegment(segment: "x", hintKey: "error.input.hint.invalidCharacter"))
		} else {
			XCTFail("Expected invalid character hint")
		}

		if case let .failure(error) = parser.parseResult("2d") {
			XCTAssertEqual(error, .invalidSegment(segment: "2d", hintKey: "error.input.hint.missingSides"))
		} else {
			XCTFail("Expected missing sides hint")
		}
	}

	func testParseRespectsV1Bounds() {
		XCTAssertNil(parser.parse("0d6"))
		XCTAssertNil(parser.parse("31d6"))
		XCTAssertNil(parser.parse("1d1"))
		XCTAssertNil(parser.parse("1d101"))

		let lowerBound = parser.parse("1d2")
		XCTAssertNotNil(lowerBound)
		XCTAssertEqual(lowerBound?.diceCount, 1)
		XCTAssertEqual(lowerBound?.sideCount, 2)

		let upperBound = parser.parse("30d100")
		XCTAssertNotNil(upperBound)
		XCTAssertEqual(upperBound?.diceCount, 30)
		XCTAssertEqual(upperBound?.sideCount, 100)
	}

	func testParseAcceptsUpperBoundIntuitiveNotation() {
		let configuration = parser.parse("30d100i")
		XCTAssertNotNil(configuration)
		XCTAssertEqual(configuration?.diceCount, 30)
		XCTAssertEqual(configuration?.sideCount, 100)
		XCTAssertEqual(configuration?.intuitive, true)
	}

	func testParseRejectsEdgeOutOfBoundsNotation() {
		XCTAssertNil(parser.parse("31d100i"))
		XCTAssertNil(parser.parse("30d101i"))
		XCTAssertNil(parser.parse("20d6+20d6"))
	}

	func testTrueRandomRollerUsesProvidedRandomSourceAndRange() {
		var capturedRange: ClosedRange<Int>?
		let roller = TrueRandomRoller { range in
			capturedRange = range
			return range.upperBound
		}

		let result = roller.roll(sideCount: 12)
		XCTAssertEqual(result, 12)
		XCTAssertEqual(capturedRange, 1...12)
	}

	func testTrueRandomRollerProducesExpectedCountAndRange() {
		let roller = TrueRandomRoller()
		let rolls = (0..<300).map { _ in roller.roll(sideCount: 10) }

		XCTAssertEqual(rolls.count, 300)
		XCTAssertTrue(rolls.allSatisfy { (1...10).contains($0) })
	}

	func testTrueRandomRollerD6StatisticalSmoke() {
		let roller = TrueRandomRoller()
		let rolls = (0..<6000).map { _ in roller.roll(sideCount: 6) }
		var counts = Array(repeating: 0, count: 6)
		for roll in rolls {
			counts[roll - 1] += 1
		}

		for count in counts {
			XCTAssertGreaterThan(count, 700)
			XCTAssertLessThan(count, 1300)
		}
	}

	func testIntuitiveRollerFallsBackWhenNotInIntuitiveMode() {
		var fallbackCalls = 0
		let roller = IntuitiveRoller(
			fallbackRoller: TrueRandomRoller { _ in
				fallbackCalls += 1
				return 4
			},
			randomDouble: { 0.5 }
		)

		let context = IntuitiveRollContext(
			sideCount: 6,
			numDiceBeingRolled: 3,
			totalRolls: 12,
			persistentTotals: [2, 2, 2, 2, 2, 2],
			sortedTotals: [2, 2, 2, 2, 2, 2]
		)

		let result = roller.roll(context: context, intuitive: false)
		XCTAssertEqual(result, 4)
		XCTAssertEqual(fallbackCalls, 1)
	}

	func testIntuitiveRollerFallsBackWhenNoLocalTotalsExist() {
		var fallbackCalls = 0
		let roller = IntuitiveRoller(
			fallbackRoller: TrueRandomRoller { _ in
				fallbackCalls += 1
				return 2
			},
			randomDouble: { 0.0 }
		)

		let context = IntuitiveRollContext(
			sideCount: 6,
			numDiceBeingRolled: 1,
			totalRolls: 2,
			persistentTotals: [0, 0, 0, 0, 0, 0],
			sortedTotals: [0, 0, 0, 0, 0, 0]
		)

		let result = roller.roll(context: context, intuitive: true)
		XCTAssertEqual(result, 2)
		XCTAssertEqual(fallbackCalls, 1)
	}

	func testIntuitiveRollerAvoidsOverrepresentedFaceWhenThresholdMet() {
		let rollerLowSample = IntuitiveRoller(
			fallbackRoller: TrueRandomRoller { _ in 1 },
			randomDouble: { 0.0 }
		)
		let rollerHighSample = IntuitiveRoller(
			fallbackRoller: TrueRandomRoller { _ in 1 },
			randomDouble: { 0.99 }
		)

		let context = IntuitiveRollContext(
			sideCount: 6,
			numDiceBeingRolled: 1,
			totalRolls: 10,
			persistentTotals: [10, 0, 0, 0, 0, 0],
			sortedTotals: [10, 0, 0, 0, 0, 0]
		)

		let lowResult = rollerLowSample.roll(context: context, intuitive: true)
		let highResult = rollerHighSample.roll(context: context, intuitive: true)

		XCTAssertEqual(lowResult, 2)
		XCTAssertEqual(highResult, 6)
	}

	func testIntuitiveRollerUsesBoundaryWeightsDeterministically() {
		let context = IntuitiveRollContext(
			sideCount: 3,
			numDiceBeingRolled: 2,
			totalRolls: 4,
			persistentTotals: [2, 1, 1],
			sortedTotals: [2, 1, 1]
		)

		let low = IntuitiveRoller(randomDouble: { 0.10 }).roll(context: context, intuitive: true)
		let mid = IntuitiveRoller(randomDouble: { 0.30 }).roll(context: context, intuitive: true)
		let high = IntuitiveRoller(randomDouble: { 0.90 }).roll(context: context, intuitive: true)

		XCTAssertEqual(low, 1)
		XCTAssertEqual(mid, 2)
		XCTAssertEqual(high, 3)
	}

	func testRollSessionTracksTotalsAcrossRollsInSameMode() {
		let session = DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { _ in 1 }, randomDouble: { 0.0 }))

		let first = session.roll(RollConfiguration(diceCount: 2, sideCount: 6, intuitive: false))
		XCTAssertEqual(first.totalRolls, 2)
		XCTAssertEqual(first.sum, 2)
		XCTAssertEqual(first.sessionTotals.first, 2)

		let second = session.roll(RollConfiguration(diceCount: 3, sideCount: 6, intuitive: false))
		XCTAssertEqual(second.totalRolls, 5)
		XCTAssertEqual(second.sum, 3)
		XCTAssertEqual(second.sessionTotals.first, 5)
	}

	func testRollSessionResetClearsState() {
		let session = DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { _ in 1 }, randomDouble: { 0.0 }))
		_ = session.roll(RollConfiguration(diceCount: 4, sideCount: 6, intuitive: false))
		session.reset()

		let afterReset = session.roll(RollConfiguration(diceCount: 1, sideCount: 6, intuitive: false))
		XCTAssertEqual(afterReset.totalRolls, 1)
		XCTAssertEqual(afterReset.sessionTotals.first, 1)
	}

	func testRollSessionResetsWhenModeChanges() {
		let session = DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { _ in 1 }, randomDouble: { 0.0 }))
		_ = session.roll(RollConfiguration(diceCount: 3, sideCount: 6, intuitive: false))

		let switched = session.roll(RollConfiguration(diceCount: 1, sideCount: 6, intuitive: true))
		XCTAssertEqual(switched.totalRolls, 1)
		XCTAssertEqual(switched.sessionTotals.first, 1)
	}

	func testRollSessionLocalTotalsMatchSingleRollOutput() {
		let session = DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { _ in 1 }, randomDouble: { 0.0 }))
		let outcome = session.roll(RollConfiguration(diceCount: 5, sideCount: 6, intuitive: false))

		XCTAssertEqual(outcome.values, Array(repeating: 1, count: 5))
		XCTAssertEqual(outcome.localTotals[0], 5)
		XCTAssertEqual(outcome.localTotals.dropFirst().reduce(0, +), 0)
	}

	func testRollSessionTracksLongRunTotalsWithoutDrift() {
		var seed = 0
		let deterministicRoller = TrueRandomRoller { range in
			seed = (seed % range.upperBound) + 1
			return seed
		}
		let session = DiceRollSession(
			intuitiveRoller: IntuitiveRoller(
				fallbackRoller: deterministicRoller,
				randomDouble: { 0.5 }
			)
		)

		var lastOutcome: RollOutcome?
		for _ in 0..<1_000 {
			lastOutcome = session.roll(RollConfiguration(diceCount: 1, sideCount: 6, intuitive: false))
		}

		guard let outcome = lastOutcome else {
			return XCTFail("Expected outcome after long run")
		}
		XCTAssertEqual(outcome.totalRolls, 1_000)
		XCTAssertEqual(outcome.sessionTotals.reduce(0, +), 1_000)
		XCTAssertEqual(outcome.sessionTotals.count, 6)
	}

	func testRollSessionMixedDiceTracksPerDieSidesAndRanges() {
		var sequence = [6, 4, 3, 2, 1, 20]
		let deterministicRoller = TrueRandomRoller { range in
			while let next = sequence.first {
				sequence.removeFirst()
				if range.contains(next) {
					return next
				}
			}
			return range.lowerBound
		}
		let session = DiceRollSession(
			intuitiveRoller: IntuitiveRoller(
				fallbackRoller: deterministicRoller,
				randomDouble: { 0.5 }
			)
		)
		let config = RollConfiguration(
			pools: [
				DicePool(diceCount: 3, sideCount: 6),
				DicePool(diceCount: 2, sideCount: 4),
				DicePool(diceCount: 1, sideCount: 20)
			],
			intuitive: false
		)

		let outcome = session.roll(config)
		XCTAssertEqual(outcome.values.count, 6)
		XCTAssertEqual(outcome.sideCounts, [6, 6, 6, 4, 4, 20])
		for (value, sides) in zip(outcome.values, outcome.sideCounts) {
			XCTAssertTrue((1...sides).contains(value))
		}
	}

	func testPreferencesStoreReturnsDefaultsWhenUnset() {
		let suiteName = "DiceTests.defaults.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = DicePreferencesStore(defaults: defaults)

		let loaded = store.load()
		XCTAssertEqual(loaded, .default)
	}

	func testPreferencesStoreRoundTripSaveLoad() {
		let suiteName = "DiceTests.roundtrip.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = DicePreferencesStore(defaults: defaults)
		let expected = DiceUserPreferences(
			lastNotation: "12d10i",
			recentPresets: ["12d10i", "6d6"],
			animationsEnabled: false,
			theme: .darkMode,
			tableTexture: .wood,
			dieFinish: .stone,
			edgeOutlinesEnabled: true,
			dieColorPreferences: DiceDieColorPreferences.default.updated(sideCount: 20, preset: .crimson),
			largeFaceLabelsEnabled: true,
			customPresets: [
				DiceSavedPreset(id: "preset-1", title: "Boss Fight", notation: "4d12+2d8", pinned: true)
			],
			soundPack: .hardTable,
			soundEffectsEnabled: false,
			hapticsEnabled: false
		)

		store.save(expected)

		let loaded = store.load()
		XCTAssertEqual(loaded, expected)
	}

	func testPreferencesStoreRecentPresetOrderingDedupAndLimit() {
		let suiteName = "DiceTests.recent.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = DicePreferencesStore(defaults: defaults, maxRecentPresets: 3)

		store.addRecentPreset("6d6")
		store.addRecentPreset("8d10")
		store.addRecentPreset("6d6")
		store.addRecentPreset("4d4")
		store.addRecentPreset("20d6")

		let loaded = store.load()
		XCTAssertEqual(loaded.recentPresets, ["20d6", "4d4", "6d6"])
	}

	func testPreferencesStoreMigratesLegacyVisualRawValues() {
		let suiteName = "DiceTests.preferences.migration.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		defaults.set("subtle", forKey: "Dice.animationIntensity")
		defaults.set("classic", forKey: "Dice.theme")
		defaults.set("balanced", forKey: "Dice.boardLayoutPreset")
		let store = DicePreferencesStore(defaults: defaults)

		let loaded = store.load()
		XCTAssertEqual(loaded.animationIntensity, .full)
		XCTAssertEqual(loaded.theme, .lightMode)
		XCTAssertEqual(loaded.boardLayoutPreset, .compact)
	}

	func testPreferencesStoreDefaultsSoundEffectsOffWhenVoiceOverIsActive() {
		let suiteName = "DiceTests.preferences.voiceover.default.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = DicePreferencesStore(defaults: defaults, voiceOverIsRunning: { true })

		let loaded = store.load()
		XCTAssertFalse(loaded.soundEffectsEnabled)
	}

	func testPreferencesStoreRespectsStoredSoundEffectsValueWithVoiceOverActive() {
		let suiteName = "DiceTests.preferences.voiceover.stored.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		defaults.set(true, forKey: "Dice.soundEffectsEnabled")
		let store = DicePreferencesStore(defaults: defaults, voiceOverIsRunning: { true })

		let loaded = store.load()
		XCTAssertTrue(loaded.soundEffectsEnabled)
	}

	func testRollHistoryAppendsInNewestFirstOrder() {
		let history = DiceRollHistory(maxPersistedEntries: 10)
		let first = RollHistoryEntry(timestamp: Date(timeIntervalSince1970: 1), notation: "1d6", values: [1], sum: 1, intuitive: false)
		let second = RollHistoryEntry(timestamp: Date(timeIntervalSince1970: 2), notation: "2d6", values: [1, 2], sum: 3, intuitive: false)

		history.append(first)
		history.append(second)

		XCTAssertEqual(history.sessionEntries, [second, first])
		XCTAssertEqual(history.persistedRecentEntries, [second, first])
	}

	func testRollHistoryTruncatesPersistedEntriesToLimit() {
		let history = DiceRollHistory(maxPersistedEntries: 2)
		let one = RollHistoryEntry(timestamp: Date(timeIntervalSince1970: 1), notation: "1d6", values: [1], sum: 1, intuitive: false)
		let two = RollHistoryEntry(timestamp: Date(timeIntervalSince1970: 2), notation: "1d6", values: [2], sum: 2, intuitive: false)
		let three = RollHistoryEntry(timestamp: Date(timeIntervalSince1970: 3), notation: "1d6", values: [3], sum: 3, intuitive: false)

		history.append(one)
		history.append(two)
		history.append(three)

		XCTAssertEqual(history.persistedRecentEntries, [three, two])
		XCTAssertEqual(history.sessionEntries, [three, two, one])
	}

	func testRollHistoryClearOperations() {
		let history = DiceRollHistory(maxPersistedEntries: 10)
		let entry = RollHistoryEntry(timestamp: Date(), notation: "1d6", values: [1], sum: 1, intuitive: false)
		history.append(entry)

		history.clearSession()
		XCTAssertTrue(history.sessionEntries.isEmpty)
		XCTAssertFalse(history.persistedRecentEntries.isEmpty)

		history.clearPersistedRecent()
		XCTAssertTrue(history.persistedRecentEntries.isEmpty)
	}

	func testRollHistoryStoreRoundTrip() {
		let suiteName = "DiceTests.history.store.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = DiceRollHistoryStore(defaults: defaults)
		let entries = [
			RollHistoryEntry(timestamp: Date(timeIntervalSince1970: 1), notation: "6d6", values: [1, 2, 3, 4, 5, 6], sum: 21, intuitive: false),
			RollHistoryEntry(timestamp: Date(timeIntervalSince1970: 2), notation: "6d6i", values: [1, 1, 1, 1, 1, 1], sum: 6, intuitive: true),
		]

		store.savePersistedEntries(entries)
		XCTAssertEqual(store.loadPersistedEntries(), entries)
	}

	func testRollHistoryExporterCSVAndText() {
		let exporter = RollHistoryExporter()
		let entry = RollHistoryEntry(
			timestamp: Date(timeIntervalSince1970: 0),
			notation: "2d6",
			values: [3, 4],
			sum: 7,
			intuitive: true
		)
		let text = exporter.export([entry], format: .text)
		let csv = exporter.export([entry], format: .csv)

		XCTAssertTrue(text.contains("2d6"))
		XCTAssertTrue(text.contains("intuitive"))
		XCTAssertTrue(csv.contains("timestamp,notation,mode,values,sum"))
		XCTAssertTrue(csv.contains("2d6"))
	}

	func testRollHistoryAnalyticsBuildsHistogramsPerSideCount() {
		let entries = [
			RollHistoryEntry(
				timestamp: Date(timeIntervalSince1970: 10),
				notation: "2d6+d4",
				values: [2, 6, 4],
				sum: 12,
				intuitive: false
			),
			RollHistoryEntry(
				timestamp: Date(timeIntervalSince1970: 11),
				notation: "d6 + d4",
				values: [2, 1],
				sum: 3,
				intuitive: false
			),
		]

		let histograms = RollHistoryAnalytics.histograms(entries: entries)
		let d4 = histograms.first(where: { $0.sideCount == 4 })
		let d6 = histograms.first(where: { $0.sideCount == 6 })

		XCTAssertEqual(d4?.totalSamples, 2)
		XCTAssertEqual(d4?.bins, [1, 0, 0, 1])
		XCTAssertEqual(d6?.totalSamples, 3)
		XCTAssertEqual(d6?.bins, [0, 2, 0, 0, 0, 1])
	}

	func testViewModelHistoryHistogramSummaryIncludesDiceFamilyPrefix() {
		let suiteName = "DiceTests.viewmodel.history.histogram.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults),
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { _ in 2 }, randomDouble: { 0.5 }))
		)

		_ = viewModel.rollFromInput("2d6")
		let summary = viewModel.historyHistogramSummary()
		XCTAssertNotNil(summary)
		XCTAssertTrue(summary?.contains("d6") ?? false)
	}

	func testRollHistoryAnalyticsComputesStreaksAndStrongOutlier() {
		let entries = [
			RollHistoryEntry(timestamp: Date(timeIntervalSince1970: 1), notation: "1d6", values: [6], sum: 6, intuitive: false),
			RollHistoryEntry(timestamp: Date(timeIntervalSince1970: 2), notation: "1d6", values: [6], sum: 6, intuitive: false),
			RollHistoryEntry(timestamp: Date(timeIntervalSince1970: 3), notation: "1d6", values: [6], sum: 6, intuitive: false),
			RollHistoryEntry(timestamp: Date(timeIntervalSince1970: 4), notation: "1d6", values: [1], sum: 1, intuitive: false),
			RollHistoryEntry(timestamp: Date(timeIntervalSince1970: 5), notation: "3d6", values: [6, 6, 6], sum: 18, intuitive: false),
		]

		let indicators = RollHistoryAnalytics.indicators(entries: entries)
		XCTAssertGreaterThanOrEqual(indicators.highStreak, 3)
		XCTAssertGreaterThanOrEqual(indicators.lowStreak, 1)
		XCTAssertEqual(indicators.outlierNotation, "3d6")
		XCTAssertTrue((indicators.outlierZScore ?? 0) > 2.0)
	}

	func testRollHistoryAnalyticsFiltersByNotationModeAndDateRange() {
		let now = Date(timeIntervalSince1970: 10_000)
		let entries = [
			RollHistoryEntry(
				timestamp: now.addingTimeInterval(-2 * 60 * 60),
				notation: "3d6+1d4",
				values: [2, 4, 6, 3],
				sum: 15,
				intuitive: false
			),
			RollHistoryEntry(
				timestamp: now.addingTimeInterval(-5 * 24 * 60 * 60),
				notation: "2d6i",
				values: [1, 2],
				sum: 3,
				intuitive: true
			),
			RollHistoryEntry(
				timestamp: now.addingTimeInterval(-40 * 24 * 60 * 60),
				notation: "1d20",
				values: [20],
				sum: 20,
				intuitive: false
			),
		]

		let searchFilter = RollHistoryFilter(searchText: "d4", mode: .all, dateRange: .all)
		let searchResult = RollHistoryAnalytics.filteredEntries(entries: entries, filter: searchFilter, now: now)
		XCTAssertEqual(searchResult.count, 1)
		XCTAssertEqual(searchResult.first?.notation, "3d6+1d4")

		let modeFilter = RollHistoryFilter(searchText: "", mode: .intuitive, dateRange: .all)
		let modeResult = RollHistoryAnalytics.filteredEntries(entries: entries, filter: modeFilter, now: now)
		XCTAssertEqual(modeResult.count, 1)
		XCTAssertEqual(modeResult.first?.notation, "2d6i")

		let rangeFilter = RollHistoryFilter(searchText: "", mode: .all, dateRange: .last7Days)
		let rangeResult = RollHistoryAnalytics.filteredEntries(entries: entries, filter: rangeFilter, now: now)
		XCTAssertEqual(rangeResult.count, 2)
	}

	func testRollHistoryAnalyticsSessionSummaryComputesRollAndNotationHighlights() {
		let entries = [
			RollHistoryEntry(timestamp: Date(timeIntervalSince1970: 3), notation: "2d6", values: [2, 3], sum: 5, intuitive: false),
			RollHistoryEntry(timestamp: Date(timeIntervalSince1970: 2), notation: "1d20", values: [17], sum: 17, intuitive: false),
			RollHistoryEntry(timestamp: Date(timeIntervalSince1970: 1), notation: "2d6", values: [6, 6], sum: 12, intuitive: false),
		]

		let summary = RollHistoryAnalytics.sessionSummary(entries: entries)
		XCTAssertEqual(summary.rollCount, 3)
		XCTAssertEqual(summary.totalDiceRolled, 5)
		XCTAssertEqual(summary.topNotation, "2d6")
		XCTAssertEqual(summary.latestNotation, "2d6")
		XCTAssertEqual(summary.latestSum, 5)
	}

	func testViewModelHistoryIndicatorsFlagHighlightsForLongHighStreaks() {
		let suiteName = "DiceTests.viewmodel.history.indicators.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults),
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { _ in 6 }, randomDouble: { 0.5 }))
		)

		_ = viewModel.rollFromInput("1d6")
		_ = viewModel.rollCurrent()
		_ = viewModel.rollCurrent()
		let indicators = viewModel.historyIndicators()
		XCTAssertGreaterThanOrEqual(indicators.highStreak, 3)
		XCTAssertTrue(indicators.hasHighlights)
	}

	func testViewModelRollFromInputUpdatesConfigurationAndDiceCount() {
		let suiteName = "DiceTests.viewmodel.roll.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults),
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { _ in 3 }, randomDouble: { 0.5 }))
		)

		let result = viewModel.rollFromInput("4d8")
		guard case let .success(outcome) = result else {
			return XCTFail("Expected success")
		}

		XCTAssertEqual(viewModel.configuration.diceCount, 4)
		XCTAssertEqual(viewModel.configuration.sideCount, 8)
		XCTAssertEqual(viewModel.diceValues.count, 4)
		XCTAssertEqual(outcome.values.count, 4)
	}

	func testViewModelRerollDieReturnsSingleOutcomeAndUpdatesValue() {
		let suiteName = "DiceTests.viewmodel.reroll.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults),
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { _ in 5 }, randomDouble: { 0.5 }))
		)

		_ = viewModel.rollFromInput("3d6")
		let outcome = viewModel.rerollDie(at: 1)

		XCTAssertNotNil(outcome)
		XCTAssertEqual(outcome?.values.count, 1)
		XCTAssertEqual(viewModel.diceValues.count, 3)
		XCTAssertEqual(viewModel.diceValues[1], 5)
	}

	func testViewModelShakeToRollUsesCurrentConfiguration() {
		let suiteName = "DiceTests.viewmodel.shake.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults),
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { _ in 2 }, randomDouble: { 0.5 }))
		)

		_ = viewModel.rollFromInput("2d10")
		let outcome = viewModel.shakeToRoll()

		XCTAssertEqual(outcome.values.count, 2)
		XCTAssertEqual(viewModel.configuration.notation, "2d10")
	}

	func testViewModelResetStatsResetsSessionTotalsForNextRoll() {
		let suiteName = "DiceTests.viewmodel.reset.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults),
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { _ in 1 }, randomDouble: { 0.5 }))
		)

		_ = viewModel.rollFromInput("3d6")
		_ = viewModel.rollCurrent()
		viewModel.resetStats()
		let outcome = viewModel.rollCurrent()

		XCTAssertEqual(outcome.totalRolls, 3)
		XCTAssertEqual(outcome.sessionTotals[0], 3)
	}

	func testViewModelHistoryEntriesTrackSessionRolls() {
		let suiteName = "DiceTests.viewmodel.history.entries.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults),
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { _ in 2 }, randomDouble: { 0.5 }))
		)

		_ = viewModel.rollFromInput("1d6")
		_ = viewModel.rollCurrent()

		XCTAssertEqual(viewModel.historyEntries.count, 2)
	}

	func testViewModelClearHistoryRemovesSessionAndPersistedEntries() {
		let suiteName = "DiceTests.viewmodel.history.clear.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let historyStore = DiceRollHistoryStore(defaults: defaults)
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: historyStore,
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { _ in 3 }, randomDouble: { 0.5 }))
		)

		_ = viewModel.rollFromInput("2d6")
		viewModel.clearHistory()

		XCTAssertTrue(viewModel.historyEntries.isEmpty)
		XCTAssertTrue(historyStore.loadPersistedEntries().isEmpty)
	}

	func testViewModelClearRecentAndPersistedActionsAreIndependent() {
		let suiteName = "DiceTests.viewmodel.history.clear.split.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let historyStore = DiceRollHistoryStore(defaults: defaults)
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: historyStore,
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { _ in 3 }, randomDouble: { 0.5 }))
		)

		_ = viewModel.rollFromInput("2d6")
		viewModel.clearRecentHistory()
		XCTAssertTrue(viewModel.historyEntries.isEmpty)
		XCTAssertFalse(historyStore.loadPersistedEntries().isEmpty)

		viewModel.clearPersistedHistory()
		XCTAssertTrue(historyStore.loadPersistedEntries().isEmpty)
	}

	func testViewModelExportHistoryProvidesTextAndCSV() {
		let suiteName = "DiceTests.viewmodel.history.export.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults),
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { _ in 4 }, randomDouble: { 0.5 }))
		)

		_ = viewModel.rollFromInput("2d6")
		let text = viewModel.exportHistory(format: .text)
		let csv = viewModel.exportHistory(format: .csv)

		XCTAssertTrue(text.contains("2d6"))
		XCTAssertTrue(csv.contains("timestamp,notation,mode,values,sum"))
	}

	func testViewModelRecentPresetsReflectLatestNotation() {
		let suiteName = "DiceTests.viewmodel.presets.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		_ = viewModel.rollFromInput("7d8")
		_ = viewModel.rollFromInput("2d20")

		XCTAssertEqual(viewModel.recentPresets.prefix(2), ["2d20", "7d8"])
	}

	func testViewModelCreateCustomPresetValidatesNotationAndPersists() {
		let suiteName = "DiceTests.viewmodel.custompresets.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferencesStore = DicePreferencesStore(defaults: defaults)
		let viewModel = DiceViewModel(
			preferencesStore: preferencesStore,
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		let success = viewModel.createCustomPreset(title: "Mixed", notation: "3d6+2d4")
		XCTAssertNoThrow(try success.get())
		XCTAssertEqual(viewModel.customPresets.count, 1)
		XCTAssertEqual(viewModel.customPresets.first?.title, "Mixed")

		let failure = viewModel.createCustomPreset(title: "Broken", notation: "3x6")
		if case let .failure(error) = failure {
			XCTAssertEqual(error, .invalidSegment(segment: "x", hintKey: "error.input.hint.invalidCharacter"))
		} else {
			XCTFail("Expected invalid notation failure")
		}
	}

	func testViewModelRollFromInputInvalidNotationReturnsStructuredError() {
		let suiteName = "DiceTests.viewmodel.invalid.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		let result = viewModel.rollFromInput("200d6")
		guard case .failure(let error) = result else {
			return XCTFail("Expected failure for out-of-bounds input")
		}
		XCTAssertEqual(error, .outOfBounds(diceBounds: 1...30, sideBounds: 2...100))
	}

	func testViewModelRepeatLastRollReusesMostRecentRolledConfiguration() {
		let suiteName = "DiceTests.viewmodel.repeat.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults),
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { $0.lowerBound }, randomDouble: { 0.5 }))
		)

		_ = viewModel.rollFromInput("2d8")
		_ = viewModel.rollFromInput("1d4")
		let repeated = viewModel.repeatLastRoll()

		XCTAssertEqual(viewModel.configuration.notation, "1d4")
		XCTAssertEqual(repeated.values.count, 1)
		XCTAssertEqual(repeated.sideCounts, [4])
	}

	func testViewModelLockedDiceRemainHeldDuringSubsequentRolls() {
		let suiteName = "DiceTests.viewmodel.locked.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		var nextValue = 0
		let fallback = TrueRandomRoller { range in
			nextValue += 1
			return min(range.upperBound, max(range.lowerBound, nextValue))
		}
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults),
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: fallback, randomDouble: { 0.5 }))
		)

		_ = viewModel.rollFromInput("3d6")
		XCTAssertEqual(viewModel.diceValues, [1, 2, 3])
		viewModel.toggleDieLock(at: 1)
		XCTAssertTrue(viewModel.isDieLocked(at: 1))

		_ = viewModel.rollCurrent()
		XCTAssertEqual(viewModel.diceValues, [4, 2, 5])
	}

	func testViewModelLockedDiceDoNotIncreaseSessionRollCount() {
		let suiteName = "DiceTests.viewmodel.locked.stats.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		var nextValue = 0
		let fallback = TrueRandomRoller { range in
			nextValue += 1
			return min(range.upperBound, max(range.lowerBound, nextValue))
		}
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults),
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: fallback, randomDouble: { 0.5 }))
		)

		let first = viewModel.rollFromInput("3d6")
		if case let .success(outcome) = first {
			XCTAssertEqual(outcome.totalRolls, 3)
		} else {
			XCTFail("Expected initial roll success")
		}
		viewModel.toggleDieLock(at: 1)
		let second = viewModel.rollCurrent()
		XCTAssertEqual(second.totalRolls, 5)
		XCTAssertEqual(viewModel.diceValues[1], 2)
	}

	func testViewModelFormattedTotalsShowsMixedModeForMixedPoolNotation() {
		let suiteName = "DiceTests.viewmodel.stats.mixedmode.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults),
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { $0.lowerBound }, randomDouble: { 0.5 }))
		)

		guard case let .success(outcome) = viewModel.rollFromInput("1d20i+1d20") else {
			return XCTFail("Expected mixed mode notation to roll")
		}
		let formatted = viewModel.formattedTotalsText(outcome: outcome, boardSupportedSides: Set([4, 6, 8, 10, 12, 20]))
		XCTAssertTrue(formatted.contains("Mode: Mixed"))
	}

	func testViewModelAnimationTogglePersistsToPreferences() {
		let suiteName = "DiceTests.viewmodel.animations.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferencesStore = DicePreferencesStore(defaults: defaults)
		let viewModel = DiceViewModel(
			preferencesStore: preferencesStore,
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		XCTAssertTrue(viewModel.animationsEnabled)
		viewModel.setAnimationsEnabled(false)
		XCTAssertFalse(viewModel.animationsEnabled)
		XCTAssertFalse(preferencesStore.load().animationsEnabled)
		XCTAssertEqual(viewModel.animationIntensity, .off)
	}

	func testViewModelAnimationIntensityPersistsToPreferences() {
		let suiteName = "DiceTests.viewmodel.animationIntensity.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferencesStore = DicePreferencesStore(defaults: defaults)
		let viewModel = DiceViewModel(
			preferencesStore: preferencesStore,
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		viewModel.setAnimationIntensity(.full)
		XCTAssertEqual(viewModel.animationIntensity, .full)
		XCTAssertTrue(viewModel.animationsEnabled)
		XCTAssertEqual(preferencesStore.load().animationIntensity, .full)
	}

	func testViewModelThemeSelectionPersistsToPreferences() {
		let suiteName = "DiceTests.viewmodel.theme.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferencesStore = DicePreferencesStore(defaults: defaults)
		let viewModel = DiceViewModel(
			preferencesStore: preferencesStore,
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		XCTAssertEqual(viewModel.theme, .system)
		viewModel.setTheme(.darkMode)
		XCTAssertEqual(viewModel.theme, .darkMode)
		XCTAssertEqual(preferencesStore.load().theme, .darkMode)
	}

	func testViewModelTextureSelectionPersistsToPreferences() {
		let suiteName = "DiceTests.viewmodel.texture.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferencesStore = DicePreferencesStore(defaults: defaults)
		let viewModel = DiceViewModel(
			preferencesStore: preferencesStore,
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		XCTAssertEqual(viewModel.tableTexture, .neutral)
		viewModel.setTableTexture(.felt)
		XCTAssertEqual(viewModel.tableTexture, .felt)
		XCTAssertEqual(preferencesStore.load().tableTexture, .felt)
	}

	func testViewModelDieFinishSelectionPersistsToPreferences() {
		let suiteName = "DiceTests.viewmodel.finish.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferencesStore = DicePreferencesStore(defaults: defaults)
		let viewModel = DiceViewModel(
			preferencesStore: preferencesStore,
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		XCTAssertEqual(viewModel.dieFinish, .matte)
		viewModel.setDieFinish(.gloss)
		XCTAssertEqual(viewModel.dieFinish, .gloss)
		XCTAssertEqual(preferencesStore.load().dieFinish, .gloss)
	}

	func testViewModelEdgeOutlineTogglePersistsToPreferences() {
		let suiteName = "DiceTests.viewmodel.outlines.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferencesStore = DicePreferencesStore(defaults: defaults)
		let viewModel = DiceViewModel(
			preferencesStore: preferencesStore,
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		XCTAssertFalse(viewModel.edgeOutlinesEnabled)
		viewModel.setEdgeOutlinesEnabled(true)
		XCTAssertTrue(viewModel.edgeOutlinesEnabled)
		XCTAssertTrue(preferencesStore.load().edgeOutlinesEnabled)
	}

	func testViewModelDieColorSelectionPersistsToPreferences() {
		let suiteName = "DiceTests.viewmodel.diecolors.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferencesStore = DicePreferencesStore(defaults: defaults)
		let viewModel = DiceViewModel(
			preferencesStore: preferencesStore,
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		XCTAssertEqual(viewModel.dieColorPreset(for: 20), .ivory)
		viewModel.setDieColorPreset(.sapphire, for: 20)
		XCTAssertEqual(viewModel.dieColorPreset(for: 20), .sapphire)
		XCTAssertEqual(preferencesStore.load().dieColorPreferences.preset(for: 20), .sapphire)
	}

	func testViewModelPerDieColorOverrideIsScopedToSelectedDieIndex() {
		let suiteName = "DiceTests.viewmodel.diecolors.perdie.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults),
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { $0.lowerBound }, randomDouble: { 0.5 }))
		)

		_ = viewModel.rollFromInput("2d6")
		viewModel.setDieColorPreset(.crimson, forDieAt: 1)
		XCTAssertNil(viewModel.dieColorPreset(forDieAt: 0))
		XCTAssertEqual(viewModel.dieColorPreset(forDieAt: 1), .crimson)
	}

	func testViewModelD6PipStyleSelectionPersistsToPreferences() {
		let suiteName = "DiceTests.viewmodel.pipstyle.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferencesStore = DicePreferencesStore(defaults: defaults)
		let viewModel = DiceViewModel(
			preferencesStore: preferencesStore,
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		XCTAssertEqual(viewModel.d6PipStyle, .round)
		viewModel.setD6PipStyle(.inset)
		XCTAssertEqual(viewModel.d6PipStyle, .inset)
		XCTAssertEqual(preferencesStore.load().d6PipStyle, .inset)
	}

	func testViewModelFaceNumeralFontSelectionPersistsToPreferences() {
		let suiteName = "DiceTests.viewmodel.numeralfont.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferencesStore = DicePreferencesStore(defaults: defaults)
		let viewModel = DiceViewModel(
			preferencesStore: preferencesStore,
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		XCTAssertEqual(viewModel.faceNumeralFont, .classic)
		viewModel.setFaceNumeralFont(.serif)
		XCTAssertEqual(viewModel.faceNumeralFont, .serif)
		XCTAssertEqual(preferencesStore.load().faceNumeralFont, .serif)
	}

	func testViewModelPerDieFontOverrideIsScopedToSelectedDieIndex() {
		let suiteName = "DiceTests.viewmodel.font.perdie.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		_ = viewModel.rollFromInput("2d10")
		viewModel.setFaceNumeralFont(.mono, forDieAt: 0)
		XCTAssertEqual(viewModel.faceNumeralFont(forDieAt: 0), .mono)
		XCTAssertNil(viewModel.faceNumeralFont(forDieAt: 1))
	}

	func testViewModelLargeFaceLabelsTogglePersistsToPreferences() {
		let suiteName = "DiceTests.viewmodel.largefacelabels.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferencesStore = DicePreferencesStore(defaults: defaults)
		let viewModel = DiceViewModel(
			preferencesStore: preferencesStore,
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		XCTAssertFalse(viewModel.largeFaceLabelsEnabled)
		viewModel.setLargeFaceLabelsEnabled(true)
		XCTAssertTrue(viewModel.largeFaceLabelsEnabled)
		XCTAssertTrue(preferencesStore.load().largeFaceLabelsEnabled)
	}

	func testViewModelMotionBlurTogglePersistsToPreferences() {
		let suiteName = "DiceTests.viewmodel.motionblur.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferencesStore = DicePreferencesStore(defaults: defaults)
		let viewModel = DiceViewModel(
			preferencesStore: preferencesStore,
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		XCTAssertFalse(viewModel.motionBlurEnabled)
		viewModel.setMotionBlurEnabled(true)
		XCTAssertTrue(viewModel.motionBlurEnabled)
		XCTAssertTrue(preferencesStore.load().motionBlurEnabled)
	}

	func testViewModelBoardLayoutPresetPersistsToPreferences() {
		let suiteName = "DiceTests.viewmodel.layoutpreset.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferencesStore = DicePreferencesStore(defaults: defaults)
		let viewModel = DiceViewModel(
			preferencesStore: preferencesStore,
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		XCTAssertEqual(viewModel.boardLayoutPreset, .compact)
		viewModel.setBoardLayoutPreset(.spacious)
		XCTAssertEqual(viewModel.boardLayoutPreset, .spacious)
		XCTAssertEqual(preferencesStore.load().boardLayoutPreset, .spacious)
	}

	func testViewModelSoundPackPersistsToPreferences() {
		let suiteName = "DiceTests.viewmodel.soundpack.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferencesStore = DicePreferencesStore(defaults: defaults)
		let viewModel = DiceViewModel(
			preferencesStore: preferencesStore,
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		XCTAssertEqual(viewModel.soundPack, .off)
		viewModel.setSoundPack(.softWood)
		XCTAssertEqual(viewModel.soundPack, .softWood)
		XCTAssertEqual(preferencesStore.load().soundPack, .softWood)
	}

	func testViewModelSoundEffectsTogglePersistsToPreferences() {
		let suiteName = "DiceTests.viewmodel.sfx.toggle.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferencesStore = DicePreferencesStore(defaults: defaults)
		let viewModel = DiceViewModel(
			preferencesStore: preferencesStore,
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		XCTAssertTrue(viewModel.soundEffectsEnabled)
		viewModel.setSoundEffectsEnabled(false)
		XCTAssertFalse(viewModel.soundEffectsEnabled)
		XCTAssertFalse(preferencesStore.load().soundEffectsEnabled)
	}

	func testViewModelHapticsTogglePersistsToPreferences() {
		let suiteName = "DiceTests.viewmodel.haptics.toggle.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferencesStore = DicePreferencesStore(defaults: defaults)
		let viewModel = DiceViewModel(
			preferencesStore: preferencesStore,
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		XCTAssertTrue(viewModel.hapticsEnabled)
		viewModel.setHapticsEnabled(false)
		XCTAssertFalse(viewModel.hapticsEnabled)
		XCTAssertFalse(preferencesStore.load().hapticsEnabled)
	}

	func testViewModelResetVisualPreferencesRestoresDefaults() {
		let suiteName = "DiceTests.viewmodel.resetvisuals.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferencesStore = DicePreferencesStore(defaults: defaults)
		let viewModel = DiceViewModel(
			preferencesStore: preferencesStore,
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		viewModel.setTheme(.darkMode)
		viewModel.setTableTexture(.wood)
		viewModel.setDieFinish(.stone)
		viewModel.setEdgeOutlinesEnabled(true)
		viewModel.setDieColorPreset(.sapphire, for: 20)
		viewModel.setD6PipStyle(.inset)
		viewModel.setFaceNumeralFont(.mono)
		viewModel.setLargeFaceLabelsEnabled(true)
		viewModel.setMotionBlurEnabled(true)

		viewModel.resetVisualPreferences()

		XCTAssertEqual(viewModel.theme, .system)
		XCTAssertEqual(viewModel.tableTexture, .neutral)
		XCTAssertEqual(viewModel.dieFinish, .matte)
		XCTAssertFalse(viewModel.edgeOutlinesEnabled)
		XCTAssertEqual(viewModel.dieColorPreset(for: 20), .ivory)
		XCTAssertEqual(viewModel.d6PipStyle, .round)
		XCTAssertEqual(viewModel.faceNumeralFont, .classic)
		XCTAssertFalse(viewModel.largeFaceLabelsEnabled)
		XCTAssertFalse(viewModel.motionBlurEnabled)
	}

	func testViewModelNotationHintReturnsInlineMessageForInvalidInput() {
		let suiteName = "DiceTests.viewmodel.notationhint.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		XCTAssertNil(viewModel.notationHint(for: "3d6+2d4"))
		XCTAssertNotNil(viewModel.notationHint(for: "3x6"))
	}

	func testDieFinishPresetAppliesDistinctMaterialParameters() {
		let gloss = SCNMaterial()
		let stone = SCNMaterial()
		DiceDieFinish.gloss.apply(to: gloss)
		DiceDieFinish.stone.apply(to: stone)

		XCTAssertEqual(gloss.lightingModel, .blinn)
		XCTAssertEqual(stone.lightingModel, .lambert)
		XCTAssertGreaterThan(gloss.shininess, stone.shininess)
	}

	func testViewModelFormattedTotalsOmitsBoardWarningForSupportedMixedDice() {
		let suiteName = "DiceTests.viewmodel.board.supportedmixed.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults),
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { $0.lowerBound }, randomDouble: { 0.5 }))
		)
		let supportedBoardSides: Set<Int> = [4, 6, 8, 10, 12, 20]

		_ = viewModel.rollFromInput("3d6+2d4+d20")
		let outcome = viewModel.rollCurrent()
		let text = viewModel.formattedTotalsText(outcome: outcome, boardSupportedSides: supportedBoardSides)

		XCTAssertFalse(text.contains("3D board preview unavailable"))
	}

	func testViewModelFormattedTotalsIncludesModeAndNotationLines() {
		let suiteName = "DiceTests.viewmodel.stats.modeandnotation.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults),
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { $0.lowerBound }, randomDouble: { 0.1 }))
		)
		let supportedBoardSides: Set<Int> = [4, 6, 8, 10, 12, 20]

		_ = viewModel.rollFromInput("2d6i")
		let outcome = viewModel.rollCurrent()
		let text = viewModel.formattedTotalsText(outcome: outcome, boardSupportedSides: supportedBoardSides)

		XCTAssertTrue(text.contains("Mode: Intuitive"))
		XCTAssertTrue(text.contains("Notation: 2d6i"))
	}

	func testViewModelFormattedTotalsShowsSingleUnsupportedSideWarning() {
		let suiteName = "DiceTests.viewmodel.board.singleunsupported.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults),
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { $0.lowerBound }, randomDouble: { 0.5 }))
		)
		let supportedBoardSides: Set<Int> = [4, 6, 8, 10, 12, 20]

		_ = viewModel.rollFromInput("1d6+1d100")
		let outcome = viewModel.rollCurrent()
		let text = viewModel.formattedTotalsText(outcome: outcome, boardSupportedSides: supportedBoardSides)

		XCTAssertTrue(text.contains("d100"))
	}

	func testViewModelFormattedTotalsShowsMixedUnsupportedWarning() {
		let suiteName = "DiceTests.viewmodel.board.mixedunsupported.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults),
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { $0.lowerBound }, randomDouble: { 0.5 }))
		)
		let supportedBoardSides: Set<Int> = [4, 6, 8, 10, 12, 20]

		_ = viewModel.rollFromInput("1d30+1d100")
		let outcome = viewModel.rollCurrent()
		let text = viewModel.formattedTotalsText(outcome: outcome, boardSupportedSides: supportedBoardSides)

		XCTAssertTrue(text.contains("mixed dice sides"))
	}

	func testWatchRollViewModelTogglesModeAndUpdatesNotation() {
		let viewModel = WatchRollViewModel(
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { _ in 2 }, randomDouble: { 0.5 }))
		)

		XCTAssertFalse(viewModel.isIntuitiveMode)
		viewModel.toggleMode()
		XCTAssertTrue(viewModel.isIntuitiveMode)
		XCTAssertEqual(viewModel.currentNotation, "1d6i")
	}

	func testWatchRollViewModelRollResetsSessionWhenModeChanges() {
		let viewModel = WatchRollViewModel(
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { _ in 3 }, randomDouble: { 0.5 }))
		)

		let first = viewModel.roll()
		XCTAssertEqual(first.totalRolls, 1)
		let second = viewModel.roll()
		XCTAssertEqual(second.totalRolls, 2)

		viewModel.toggleMode()
		let afterModeChange = viewModel.roll()
		XCTAssertEqual(afterModeChange.totalRolls, 1)
	}

	func testWatchRollViewModelStatusTextReflectsModeAndCount() {
		let viewModel = WatchRollViewModel()
		XCTAssertEqual(viewModel.statusText(rollCount: 1), "TR·1d6\nr1")
		viewModel.toggleMode()
		XCTAssertEqual(viewModel.statusText(rollCount: 4), "INT·1d6i\nr4")
	}

	func testWatchRollViewModelStatusTextUsesGlanceableTokensWithLastValue() {
		let viewModel = WatchRollViewModel()
		XCTAssertEqual(viewModel.statusText(lastValue: 5), "TR·1d6\nv5")
		viewModel.toggleMode()
		XCTAssertEqual(viewModel.statusText(lastValue: 2), "INT·1d6i\nv2")
	}

	func testWatchSceneKitFlowRemainsInSyncAcrossModeSwitchAndRepeatedRolls() {
		var scripted = [1, 2, 3, 4, 5]
		let session = DiceRollSession(
			intuitiveRoller: IntuitiveRoller(
				fallbackRoller: TrueRandomRoller { _ in scripted.removeFirst() },
				randomDouble: { 0.5 }
			)
		)
		let viewModel = WatchRollViewModel(rollSession: session)

		let first = viewModel.roll().values[0]
		let second = viewModel.roll().values[0]
		let third = viewModel.roll().values[0]
		XCTAssertEqual([first, second, third], [1, 2, 3])
		XCTAssertEqual(viewModel.statusText(lastValue: third), "TR·1d6\nv3")
		_ = D6FaceOrientation.eulerAngles(for: first)
		_ = D6FaceOrientation.eulerAngles(for: second)
		_ = D6FaceOrientation.eulerAngles(for: third)

		viewModel.toggleMode()
		let afterToggle = viewModel.roll()
		XCTAssertEqual(afterToggle.totalRolls, 1)
		XCTAssertEqual(afterToggle.values, [4])
		XCTAssertEqual(viewModel.statusText(lastValue: 4), "INT·1d6i\nv4")
		_ = D6FaceOrientation.eulerAngles(for: 4)
	}

	func testD6FaceOrientationProvidesDistinctExpectedMappings() {
		XCTAssertEqual(D6FaceOrientation.eulerAngles(for: 1).y, 0, accuracy: 0.0001)
		XCTAssertEqual(D6FaceOrientation.eulerAngles(for: 2).y, -Float.pi / 2, accuracy: 0.0001)
		XCTAssertEqual(D6FaceOrientation.eulerAngles(for: 3).y, Float.pi, accuracy: 0.0001)
		XCTAssertEqual(D6FaceOrientation.eulerAngles(for: 4).y, Float.pi / 2, accuracy: 0.0001)
		XCTAssertEqual(D6FaceOrientation.eulerAngles(for: 5).x, Float.pi / 2, accuracy: 0.0001)
		XCTAssertEqual(D6FaceOrientation.eulerAngles(for: 6).x, -Float.pi / 2, accuracy: 0.0001)
	}

	func testSharedD6RenderConfigUsesBeveledCubeAndSixFaceMaterials() {
		let geometry = D6SceneKitRenderConfig.beveledCube(sideLength: 2.0)
		XCTAssertEqual(geometry.materials.count, 6)
		XCTAssertGreaterThan(geometry.chamferRadius, 0)
		XCTAssertEqual(geometry.chamferSegmentCount, 4)

		let texture = D6SceneKitRenderConfig.faceTexture(value: 6)
		XCTAssertEqual(texture.size.width, 256, accuracy: 0.1)
		XCTAssertEqual(texture.size.height, 256, accuracy: 0.1)
	}

	func testD6PipStylesGenerateDistinctTexturesForSameFaceValue() {
		let round = D6SceneKitRenderConfig.faceTexture(value: 5, pipStyle: .round)
		let square = D6SceneKitRenderConfig.faceTexture(value: 5, pipStyle: .square)
		let inset = D6SceneKitRenderConfig.faceTexture(value: 5, pipStyle: .inset)

		let roundData = round.pngData()
		let squareData = square.pngData()
		let insetData = inset.pngData()

		XCTAssertNotNil(roundData)
		XCTAssertNotNil(squareData)
		XCTAssertNotNil(insetData)
		XCTAssertNotEqual(roundData, squareData)
		XCTAssertNotEqual(roundData, insetData)
		XCTAssertNotEqual(squareData, insetData)
	}

	func testD6PipFaceTexturesAreDistinctAcrossAllFaceValues() {
		let textures = (1...6).map { D6SceneKitRenderConfig.faceTexture(value: $0, pipStyle: .round).pngData() }
		XCTAssertTrue(textures.allSatisfy { $0 != nil })
		for i in 0..<textures.count {
			for j in (i + 1)..<textures.count {
				XCTAssertNotEqual(textures[i], textures[j], "Expected unique pip texture for faces \(i + 1) and \(j + 1)")
			}
		}
	}

	func testNonD6NumeralFontsRemainReadableAcrossDieTypeFaceSizes() {
		let dieSamples: [(sample: String, pointSize: CGFloat, canvas: CGSize, inset: CGFloat, label: String)] = [
			("4", 36, CGSize(width: 96, height: 96), 10, "d4"),
			("8", 34, CGSize(width: 96, height: 96), 10, "d8"),
			("10", 34, CGSize(width: 100, height: 100), 10, "d10"),
			("12", 32, CGSize(width: 100, height: 100), 10, "d12"),
			("20", 30, CGSize(width: 100, height: 100), 10, "d20"),
			("100", 28, CGSize(width: 100, height: 100), 10, "d100"),
		]
		for font in DiceFaceNumeralFont.allCases {
			for sample in dieSamples {
				XCTAssertTrue(
					font.isReadable(sampleText: sample.sample, pointSize: sample.pointSize, canvas: sample.canvas, inset: sample.inset),
					"Font \(font) should remain readable for \(sample.label)"
				)
			}
		}
	}

	func testDyslexiaFriendlyFontOptionProvidesNumeralAndCaptionFonts() {
		let numeral = DiceFaceNumeralFont.dyslexiaFriendly.numeralFont(ofSize: 28)
		let caption = DiceFaceNumeralFont.dyslexiaFriendly.captionFont(ofSize: 16)
		XCTAssertGreaterThan(numeral.pointSize, 0)
		XCTAssertGreaterThan(caption.pointSize, 0)
	}

	func testLargeFaceLabelSizingIncreasesTextureAndFallbackSizes() {
		let normalTexture = DiceFaceLabelSizing.textureNumeralPointSize(sideCount: 20, large: false)
		let largeTexture = DiceFaceLabelSizing.textureNumeralPointSize(sideCount: 20, large: true)
		XCTAssertGreaterThan(largeTexture, normalTexture)

		let normalD4 = DiceFaceLabelSizing.textureNumeralPointSize(sideCount: 4, large: false)
		let largeD4 = DiceFaceLabelSizing.textureNumeralPointSize(sideCount: 4, large: true)
		XCTAssertGreaterThan(largeD4, normalD4)

		let normalFallback = DiceFaceLabelSizing.staticFallbackPointSize(cellSideLength: 80, large: false)
		let largeFallback = DiceFaceLabelSizing.staticFallbackPointSize(cellSideLength: 80, large: true)
		XCTAssertGreaterThan(largeFallback, normalFallback)
	}

	func testReducedMotionProfileLowersEnergyAndDuration() {
		let normal = DiceMotionBehaviorProfile.resolve(intensity: .full, reduceMotionEnabled: false)
		let reduced = DiceMotionBehaviorProfile.resolve(intensity: .full, reduceMotionEnabled: true)

		XCTAssertGreaterThan(normal.duration, reduced.duration)
		XCTAssertGreaterThan(normal.motionScale, reduced.motionScale)
		XCTAssertGreaterThan(normal.liftMultiplier, reduced.liftMultiplier)
		XCTAssertGreaterThan(normal.oscillationAmplitude, reduced.oscillationAmplitude)
	}

	func testOffAnimationIntensityUsesZeroMotionProfile() {
		let profile = DiceMotionBehaviorProfile.resolve(intensity: .off, reduceMotionEnabled: false)
		XCTAssertEqual(profile.duration, 0)
		XCTAssertEqual(profile.motionScale, 0)
		XCTAssertEqual(profile.liftMultiplier, 0)
		XCTAssertEqual(profile.oscillationAmplitude, 0)
	}

	func testFaceContrastCalibrationKeepsReadableInkAcrossFaceFills() {
		let fills: [UIColor] = [
			UIColor(white: 0.98, alpha: 1.0),
			UIColor(white: 0.80, alpha: 1.0),
			UIColor(white: 0.35, alpha: 1.0),
			UIColor(white: 0.08, alpha: 1.0),
			UIColor(red: 0.70, green: 0.18, blue: 0.18, alpha: 1.0),
		]

		for fill in fills {
			let style = DiceFaceContrast.style(for: fill)
			XCTAssertGreaterThanOrEqual(DiceFaceContrast.contrastRatio(style.primaryInkColor, style.fillColor), 4.5)
			XCTAssertGreaterThanOrEqual(DiceFaceContrast.contrastRatio(style.borderColor, style.fillColor), 1.5)
		}
	}

	func testIndependentViewModelsMaintainIsolatedActiveDiceSets() {
		let suiteName = "DiceTests.multiwindow.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }

		let first = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults),
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { _ in 1 }, randomDouble: { 0.5 }))
		)
		let second = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults),
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { _ in 2 }, randomDouble: { 0.5 }))
		)

		_ = first.rollFromInput("2d6")
		_ = second.rollFromInput("4d6")

		XCTAssertEqual(first.diceValues, [1, 1])
		XCTAssertEqual(second.diceValues, [2, 2, 2, 2])
	}

	func testControllerExposesKeyboardCommandsForCatalystParity() {
		let controller = DiceCollectionViewController(collectionViewLayout: UICollectionViewFlowLayout())
		let commands = controller.keyCommands ?? []
		let commandInputs = Set(commands.compactMap(\.input))
		XCTAssertTrue(commandInputs.contains("r"))
		XCTAssertTrue(commandInputs.contains("h"))
		XCTAssertTrue(commandInputs.contains("f"))
	}

	func testDieIndexFromAccessibilityIdentifierParsesExpectedFormat() {
		XCTAssertEqual(DiceCollectionViewController.dieIndexFromAccessibilityIdentifier("dieButton_0"), 0)
		XCTAssertEqual(DiceCollectionViewController.dieIndexFromAccessibilityIdentifier("dieButton_12"), 12)
	}

	func testDieIndexFromAccessibilityIdentifierRejectsInvalidValues() {
		XCTAssertNil(DiceCollectionViewController.dieIndexFromAccessibilityIdentifier(nil))
		XCTAssertNil(DiceCollectionViewController.dieIndexFromAccessibilityIdentifier("die_2"))
		XCTAssertNil(DiceCollectionViewController.dieIndexFromAccessibilityIdentifier("dieButton_"))
		XCTAssertNil(DiceCollectionViewController.dieIndexFromAccessibilityIdentifier("dieButton_x"))
	}

	func testWatchViewModelRepeatLastRollUsesPreviousModeConfiguration() {
		let model = WatchRollViewModel(
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { $0.lowerBound }, randomDouble: { 0.5 })),
			isIntuitiveMode: false
		)
		_ = model.roll()
		model.toggleMode()
		let repeated = model.repeatLastRoll()

		XCTAssertEqual(repeated.values.count, 1)
		XCTAssertEqual(repeated.sideCounts, [6])
	}

	func testD10MeshFacesArePlanar() {
		let mesh = DiceCubeView.debugMeshData(sideCount: 10)
		XCTAssertEqual(mesh.vertices.count, 12)
		XCTAssertEqual(mesh.faces.count, 10)
		for face in mesh.faces {
			XCTAssertEqual(face.count, 4)
			let a = mesh.vertices[face[0]]
			let b = mesh.vertices[face[1]]
			let c = mesh.vertices[face[2]]
			let d = mesh.vertices[face[3]]
			let volume6 = simd_dot(b - a, simd_cross(c - a, d - a))
			XCTAssertEqual(volume6, 0, accuracy: 0.0001, "Non-planar face indices: \(face)")
		}
	}

	func testD4MeshGeometryMatchesTetrahedronExpectations() {
		let mesh = DiceCubeView.debugMeshData(sideCount: 4)
		XCTAssertEqual(mesh.vertices.count, 4)
		XCTAssertEqual(mesh.faces.count, 4)
		for face in mesh.faces {
			XCTAssertEqual(face.count, 3)
			let uniqueIndices = Set(face)
			XCTAssertEqual(uniqueIndices.count, 3)
		}
	}

	func testHistoryRowFormatterIncludesExplicitTimeAndValuesLabels() {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.timeZone = TimeZone(secondsFromGMT: 0)
		formatter.dateFormat = "HH:mm"
		let entry = RollHistoryEntry(
			timestamp: Date(timeIntervalSince1970: 16 * 3600 + 27 * 60),
			notation: "6d10",
			values: [2, 4, 6, 8, 10, 1],
			sum: 31,
			intuitive: false
		)

		let detail = HistoryRowFormatter.subtitle(for: entry, dateFormatter: formatter)
		XCTAssertEqual(detail, "Time: 16:27 • Values: 2, 4, 6, 8, 10, 1")
	}

	func testD4FacesUseVertexLabelTriples() {
		let labels = DiceCubeView.debugD4FaceVertexLabels()
		XCTAssertEqual(labels.count, 4)
		XCTAssertEqual(labels[0], [1, 2, 3])
		XCTAssertEqual(labels[1], [1, 4, 2])
		XCTAssertEqual(labels[2], [1, 3, 4])
		XCTAssertEqual(labels[3], [2, 4, 3])
	}

	func testD4OrientationMapsRollValueToCameraFacingVertex() {
		for value in 1...4 {
			XCTAssertEqual(DiceCubeView.debugD4TopVertex(for: value), value)
		}
	}

	func testD4LabelLayoutInsetsAndOrientsTowardOppositeEdgeMidpoints() {
		let size = CGSize(width: 256, height: 256)
		let layout = DiceCubeView.debugD4LabelLayout(size: size)
		XCTAssertEqual(layout.triangle.count, 3)
		XCTAssertEqual(layout.placements.count, 3)

		func normalized(_ point: CGPoint) -> CGPoint {
			let length = sqrt((point.x * point.x) + (point.y * point.y))
			guard length > 0.0001 else { return CGPoint(x: 0, y: 0) }
			return CGPoint(x: point.x / length, y: point.y / length)
		}

		func wrapAngle(_ angle: CGFloat) -> CGFloat {
			var wrapped = angle
			while wrapped > .pi { wrapped -= 2 * .pi }
			while wrapped < -.pi { wrapped += 2 * .pi }
			return wrapped
		}

		for index in 0..<3 {
			let vertex = layout.triangle[index]
			let otherA = layout.triangle[(index + 1) % 3]
			let otherB = layout.triangle[(index + 2) % 3]
			let oppositeMid = CGPoint(x: (otherA.x + otherB.x) * 0.5, y: (otherA.y + otherB.y) * 0.5)
			let towardOpposite = CGPoint(x: oppositeMid.x - vertex.x, y: oppositeMid.y - vertex.y)
			let placement = layout.placements[index]
			let toLabel = CGPoint(x: placement.position.x - vertex.x, y: placement.position.y - vertex.y)

			// Labels should be inset from each vertex by roughly one-third of the altitude.
			let insetRatio = sqrt((toLabel.x * toLabel.x) + (toLabel.y * toLabel.y)) / sqrt((towardOpposite.x * towardOpposite.x) + (towardOpposite.y * towardOpposite.y))
			XCTAssertEqual(insetRatio, 0.34, accuracy: 0.02)

			let expectedDown = normalized(towardOpposite)
			let renderedDown = CGPoint(x: -sin(placement.angle), y: cos(placement.angle))
			XCTAssertEqual(renderedDown.x, expectedDown.x, accuracy: 0.02)
			XCTAssertEqual(renderedDown.y, expectedDown.y, accuracy: 0.02)

			let expectedAngle = atan2(towardOpposite.y, towardOpposite.x) - (.pi / 2)
			XCTAssertEqual(wrapAngle(placement.angle - expectedAngle), 0, accuracy: 0.02)
		}
	}

	func testVisualSnapshot_iPhoneLightMixedDice() {
		let hash = visualSnapshotHash(
			theme: .lightMode,
			layout: .iphone,
			values: [3, 5, 2, 17, 8, 11],
			sideCounts: [6, 6, 4, 20, 8, 10]
		)
		XCTAssertEqual(hash, "00699cbfe309afb8")
	}

	func testVisualSnapshot_iPadDarkMixedDice() {
		let hash = visualSnapshotHash(
			theme: .darkMode,
			layout: .ipad,
			values: [12, 4, 6, 19, 7, 2, 9, 15],
			sideCounts: [20, 6, 6, 20, 10, 4, 8, 12]
		)
		XCTAssertEqual(hash, "fc96f651d30b9d72")
	}

	func testVisualSnapshot_macSystemMixedDice() {
		let hash = visualSnapshotHash(
			theme: .system,
			layout: .macCatalyst,
			values: [1, 6, 10, 14, 4, 8, 2, 11, 20],
			sideCounts: [4, 6, 10, 12, 6, 8, 4, 20, 20]
		)
		XCTAssertEqual(hash, "3624d848cb91f989")
	}

	private enum SnapshotLayout {
		case iphone
		case ipad
		case macCatalyst

		var canvasSize: CGSize {
			switch self {
			case .iphone: return CGSize(width: 390, height: 844)
			case .ipad: return CGSize(width: 1024, height: 1366)
			case .macCatalyst: return CGSize(width: 1280, height: 800)
			}
		}

		var columns: Int {
			switch self {
			case .iphone: return 3
			case .ipad: return 4
			case .macCatalyst: return 5
			}
		}
	}

	private func visualSnapshotHash(theme: DiceTheme, layout: SnapshotLayout, values: [Int], sideCounts: [Int]) -> String {
		XCTAssertEqual(values.count, sideCounts.count)
		let image = visualSnapshotImage(theme: theme, layout: layout, values: values, sideCounts: sideCounts)
		guard let data = image.pngData() else {
			XCTFail("Expected snapshot PNG data")
			return ""
		}
		return fnv1a64Hex(data)
	}

	private func visualSnapshotImage(theme: DiceTheme, layout: SnapshotLayout, values: [Int], sideCounts: [Int]) -> UIImage {
		let palette = theme.palette
		let size = layout.canvasSize
		let renderer = UIGraphicsImageRenderer(size: size)
		return renderer.image { context in
			let cg = context.cgContext
			palette.screenBackgroundColor.setFill()
			cg.fill(CGRect(origin: .zero, size: size))

			let boardRect = CGRect(x: 24, y: 120, width: size.width - 48, height: size.height - 180)
			let board = UIBezierPath(roundedRect: boardRect, cornerRadius: 16)
			palette.panelBackgroundColor.setFill()
			board.fill()

			let textAttrs: [NSAttributedString.Key: Any] = [
				.font: UIFont.systemFont(ofSize: 28, weight: .semibold),
				.foregroundColor: palette.secondaryTextColor
			]
			("Snapshot \(theme.rawValue)" as NSString).draw(at: CGPoint(x: 28, y: 60), withAttributes: textAttrs)

			let columns = layout.columns
			let spacing: CGFloat = 18
			let availableWidth = boardRect.width - CGFloat(columns - 1) * spacing - 24
			let dieSide = floor(availableWidth / CGFloat(columns))
			let rows = Int(ceil(Double(values.count) / Double(columns)))
			let totalHeight = CGFloat(rows) * dieSide + CGFloat(max(0, rows - 1)) * spacing
			let originY = boardRect.minY + max(16, (boardRect.height - totalHeight) * 0.5)

			for index in values.indices {
				let row = index / columns
				let column = index % columns
				let x = boardRect.minX + 12 + CGFloat(column) * (dieSide + spacing)
				let y = originY + CGFloat(row) * (dieSide + spacing)
				let rect = CGRect(x: x, y: y, width: dieSide, height: dieSide).insetBy(dx: 4, dy: 4)
				drawSnapshotDie(in: cg, rect: rect, value: values[index], sideCount: sideCounts[index], palette: palette)
			}
		}
	}

	private func drawSnapshotDie(in context: CGContext, rect: CGRect, value: Int, sideCount: Int, palette: DiceThemePalette) {
		let preset = DiceDieColorPreferences.default.preset(for: sideCount)
		let path = snapshotPath(for: sideCount, in: rect)
		context.saveGState()
		context.addPath(path.cgPath)
		context.setFillColor(preset.fillColor.cgColor)
		context.fillPath()
		context.restoreGState()

		context.saveGState()
		context.addPath(path.cgPath)
		context.setStrokeColor(palette.secondaryTextColor.cgColor)
		context.setLineWidth(2)
		context.strokePath()
		context.restoreGState()

		let fontSize = max(16, rect.width * 0.28)
		let attrs: [NSAttributedString.Key: Any] = [
			.font: DiceFaceNumeralFont.classic.numeralFont(ofSize: fontSize),
			.foregroundColor: DiceFaceContrast.style(for: preset.fillColor).primaryInkColor
		]
		let text = "\(value)" as NSString
		let textSize = text.size(withAttributes: attrs)
		let point = CGPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2)
		text.draw(at: point, withAttributes: attrs)
	}

	private func snapshotPath(for sideCount: Int, in rect: CGRect) -> UIBezierPath {
		let sides: Int
		switch sideCount {
		case 4: sides = 3
		case 6: sides = 4
		case 8: sides = 8
		case 10: sides = 10
		case 12: sides = 6
		case 20: sides = 10
		default: sides = 6
		}
		let center = CGPoint(x: rect.midX, y: rect.midY)
		let radius = min(rect.width, rect.height) * 0.48
		let path = UIBezierPath()
		for i in 0..<sides {
			let angle = -CGFloat.pi / 2 + (CGFloat(i) * 2 * .pi / CGFloat(sides))
			let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
			if i == 0 {
				path.move(to: point)
			} else {
				path.addLine(to: point)
			}
		}
		path.close()
		return path
	}

	private func fnv1a64Hex(_ data: Data) -> String {
		var hash: UInt64 = 0xcbf29ce484222325
		let prime: UInt64 = 0x100000001b3
		for byte in data {
			hash ^= UInt64(byte)
			hash = hash &* prime
		}
		return String(format: "%016llx", hash)
	}

}
