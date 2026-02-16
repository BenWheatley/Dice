//
//  DiceTests.swift
//  DiceTests
//
//  Created by Ben Wheatley on 2018/09/27.
//  Copyright © 2018 Ben Wheatley. All rights reserved.
//

import XCTest
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
		XCTAssertNil(parser.parse("d6"))
		XCTAssertNil(parser.parse("6d"))
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
		let expected = DiceUserPreferences(lastNotation: "12d10i", recentPresets: ["12d10i", "6d6"])

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

}
