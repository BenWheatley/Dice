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
import AVFoundation
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

	func testParseSupportsPerPoolColorTags() {
		let configuration = parser.parse("2d6i(red)+d6(green)+d6(blue)")
		XCTAssertNotNil(configuration)
		XCTAssertEqual(configuration?.pools, [
			DicePool(diceCount: 2, sideCount: 6, intuitive: true, colorTag: "red"),
			DicePool(diceCount: 1, sideCount: 6, intuitive: false, colorTag: "green"),
			DicePool(diceCount: 1, sideCount: 6, intuitive: false, colorTag: "blue"),
		])
		XCTAssertEqual(configuration?.notation, "2d6i(red)+1d6(green)+1d6(blue)")
	}

	func testParseRejectsUnknownColorTags() {
		if case let .failure(error) = parser.parseResult("d6(magenta)") {
			XCTAssertEqual(error, .invalidSegment(segment: "d6(magenta)", hintKey: "error.input.hint.colorTag"))
		} else {
			XCTFail("Expected color-tag parse failure")
		}
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

	func testAppRouteParsesSupportedDiceURLs() {
		XCTAssertEqual(DiceAppRoute(url: URL(string: "dice://roll")!), .roll)
		XCTAssertEqual(DiceAppRoute(url: URL(string: "dice://repeat")!), .repeatLastRoll)
		XCTAssertEqual(DiceAppRoute(url: URL(string: "dice://history")!), .history)
		XCTAssertEqual(DiceAppRoute(url: URL(string: "dice://presets")!), .presets)
	}

	func testAppRouteRejectsUnsupportedURLs() {
		XCTAssertNil(DiceAppRoute(url: URL(string: "https://example.com/roll")!))
		XCTAssertNil(DiceAppRoute(url: URL(string: "dice://unknown")!))
	}

	func testDynamicQuickActionsHideRepeatWhenNoHistory() {
		let snapshot = DiceWidgetRollSnapshot(
			notation: "6d6",
			lastTotal: 0,
			modeToken: .trueRandom,
			recentTotals: [],
			isEmptyState: true,
			themeToken: .system
		)
		let items = DiceQuickActionLibrary.dynamicItems(for: snapshot)
		XCTAssertFalse(items.map(\.type).contains(DiceQuickActionType.repeatLastRoll.shortcutType))
	}

	func testDynamicQuickActionsIncludeRepeatWhenHistoryExists() {
		let snapshot = DiceWidgetRollSnapshot(
			notation: "3d20+1d6",
			lastTotal: 44,
			modeToken: .intuitive,
			recentTotals: [44, 38, 27],
			isEmptyState: false,
			themeToken: .darkMode
		)
		let items = DiceQuickActionLibrary.dynamicItems(for: snapshot)
		XCTAssertTrue(items.map(\.type).contains(DiceQuickActionType.repeatLastRoll.shortcutType))
		let repeatItem = items.first(where: { $0.type == DiceQuickActionType.repeatLastRoll.shortcutType })
		XCTAssertEqual(repeatItem?.localizedSubtitle, "Last: 3d20+1d6")
	}

	func testQuickActionRouteResolverReturnsRouteForKnownType() {
		let snapshot = DiceWidgetRollSnapshot(
			notation: "6d6",
			lastTotal: 18,
			modeToken: .trueRandom,
			recentTotals: [18, 21, 15],
			isEmptyState: false,
			themeToken: .system
		)
		let route = DiceQuickActionRouter.route(for: DiceQuickActionType.rollHistory.shortcutType, snapshot: snapshot)
		XCTAssertEqual(route, .history)
	}

	func testQuickActionRouteResolverRejectsUnknownType() {
		let snapshot = DiceWidgetTimelinePolicy.placeholderSnapshot
		let route = DiceQuickActionRouter.route(for: "com.kitsunesoftware.Dice.unknown", snapshot: snapshot)
		XCTAssertNil(route)
	}

	func testQuickActionRouteResolverNoopsRepeatWhenNoHistory() {
		let snapshot = DiceWidgetRollSnapshot(
			notation: "6d6",
			lastTotal: 0,
			modeToken: .trueRandom,
			recentTotals: [],
			isEmptyState: true,
			themeToken: .system
		)
		let route = DiceQuickActionRouter.route(for: DiceQuickActionType.repeatLastRoll.shortcutType, snapshot: snapshot)
		XCTAssertNil(route)
	}

	func testWidgetTimelinePolicyUsesLongerIntervalForEmptyState() {
		let snapshot = DiceWidgetRollSnapshot(
			notation: "6d6",
			lastTotal: 0,
			modeToken: .trueRandom,
			recentTotals: [],
			isEmptyState: true,
			themeToken: .system
		)
		XCTAssertEqual(DiceWidgetTimelinePolicy.refreshIntervalMinutes(for: snapshot), 120)
	}

	func testWidgetTimelinePolicyUsesShortIntervalForRecentState() {
		let snapshot = DiceWidgetRollSnapshot(
			notation: "3d20+1d6",
			lastTotal: 44,
			modeToken: .intuitive,
			recentTotals: [44, 38, 27],
			isEmptyState: false,
			themeToken: .darkMode
		)
		XCTAssertEqual(DiceWidgetTimelinePolicy.refreshIntervalMinutes(for: snapshot), 30)
	}

	func testWidgetTimelinePlaceholderFixtureIsDeterministic() {
		let fixture = DiceWidgetTimelinePolicy.placeholderSnapshot
		XCTAssertEqual(fixture.notation, "6d6")
		XCTAssertEqual(fixture.lastTotal, 21)
		XCTAssertEqual(fixture.modeToken, .trueRandom)
		XCTAssertEqual(fixture.recentTotals, [21, 18, 24])
		XCTAssertFalse(fixture.isEmptyState)
		XCTAssertEqual(fixture.themeToken, .system)
	}

	func testCubeViewDefaultsToIvoryWithoutPerDieOverride() {
		let preferences = DiceDieColorPreferences(presetsBySideCount: [6: .amber])
		let resolved = DiceCubeView.debugResolvedColorPreset(
			sideCount: 6,
			colorPresetOverride: nil,
			dieColorPreferences: preferences
		)
		XCTAssertEqual(resolved, .ivory)
	}

	func testCubeViewUsesPerDieOverrideColorWhenProvided() {
		let preferences = DiceDieColorPreferences(presetsBySideCount: [6: .amber])
		let resolved = DiceCubeView.debugResolvedColorPreset(
			sideCount: 6,
			colorPresetOverride: .crimson,
			dieColorPreferences: preferences
		)
		XCTAssertEqual(resolved, .crimson)
	}

	func testCubeViewSymbolInkColorIsDarkForLightFill() {
		let ink = DiceCubeView.debugSymbolInkColor(fillColor: .white)
		XCTAssertEqual(ink, UIColor.black)
	}

	func testCubeViewSymbolInkColorIsLightForDarkFill() {
		let ink = DiceCubeView.debugSymbolInkColor(fillColor: .black)
		XCTAssertEqual(ink, UIColor.white)
	}

	func testAudioFormatResolverPrefersPlayerOutputFormat() {
		let playerOutput = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)
		let mixerOutput = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

		let resolved = DiceAudioFormatResolver.playbackFormat(playerOutput: playerOutput, mixerOutput: mixerOutput)

		XCTAssertEqual(resolved?.sampleRate, 48_000)
		XCTAssertEqual(resolved?.channelCount, 2)
	}

	func testAudioFormatResolverFallsBackToMixerWhenPlayerOutputInvalid() {
		let invalidPlayerOutput = AVAudioFormat(standardFormatWithSampleRate: 0, channels: 0)
		let mixerOutput = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

		let resolved = DiceAudioFormatResolver.playbackFormat(playerOutput: invalidPlayerOutput, mixerOutput: mixerOutput)

		XCTAssertEqual(resolved?.sampleRate, 44_100)
		XCTAssertEqual(resolved?.channelCount, 1)
	}

	func testWidgetSnapshotStoreReturnsDefaultWhenNoPersistedState() {
		let defaults = UserDefaults(suiteName: "DiceTests.WidgetSnapshotStore.Empty.\(UUID().uuidString)")!
		let store = DiceWidgetSnapshotStore(defaults: defaults)

		let snapshot = store.loadSnapshot()

		XCTAssertEqual(snapshot.notation, "6d6")
		XCTAssertEqual(snapshot.lastTotal, 0)
		XCTAssertEqual(snapshot.modeToken, .trueRandom)
		XCTAssertTrue(snapshot.recentTotals.isEmpty)
		XCTAssertTrue(snapshot.isEmptyState)
		XCTAssertEqual(snapshot.themeToken, .system)
	}

	func testWidgetSnapshotStoreUsesPersistedNotationAndHistory() throws {
		let defaults = UserDefaults(suiteName: "DiceTests.WidgetSnapshotStore.History.\(UUID().uuidString)")!
		defaults.set("3d20+1d6", forKey: "Dice.lastNotation")
		defaults.set("darkMode", forKey: "Dice.theme")

		let history = [
			RollHistoryEntry(timestamp: Date(timeIntervalSince1970: 100), notation: "2d6", values: [4, 5], sum: 9, intuitive: false),
			RollHistoryEntry(timestamp: Date(timeIntervalSince1970: 200), notation: "3d20+1d6", values: [11, 19, 3, 5], sum: 38, intuitive: true),
			RollHistoryEntry(timestamp: Date(timeIntervalSince1970: 300), notation: "1d6", values: [2], sum: 2, intuitive: false),
		]
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		defaults.set(try encoder.encode(history), forKey: "Dice.persistedHistory")

		let store = DiceWidgetSnapshotStore(defaults: defaults)
		let snapshot = store.loadSnapshot()

		XCTAssertEqual(snapshot.notation, "3d20+1d6")
		XCTAssertEqual(snapshot.lastTotal, 2)
		XCTAssertEqual(snapshot.modeToken, .trueRandom)
		XCTAssertEqual(snapshot.recentTotals, [2, 38, 9])
		XCTAssertFalse(snapshot.isEmptyState)
		XCTAssertEqual(snapshot.themeToken, .darkMode)
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

	func testPresetPickerSeedsBuiltinsAndAppendsSavedPresetsBeforeInitialization() {
		let saved = [DiceSavedPreset(title: "My Mix", notation: "3d6+2d4")]
		let merged = PresetPickerViewController.mergedPresets(saved: saved, initialized: false)
		let notations = merged.map(\.notation)
		XCTAssertTrue(notations.contains("1d6"))
		XCTAssertTrue(notations.contains("4d6"))
		XCTAssertTrue(notations.contains("1d6i"))
		XCTAssertTrue(notations.contains("d6(red)+d20(green)"))
		XCTAssertTrue(notations.contains("d6(blue)+d4(red)"))
		XCTAssertTrue(notations.contains("3d6+2d4"))
	}

	func testPresetPickerUsesSavedPresetsAsAuthoritativeAfterInitialization() {
		let merged = PresetPickerViewController.mergedPresets(saved: [], initialized: true)
		XCTAssertTrue(merged.isEmpty)
	}

	func testPresetPickerUpdatedPresetUsesNotationAsFallbackTitle() {
		let preset = DiceSavedPreset(id: "preset-1", title: "Old", notation: "1d6")
		let result = PresetPickerViewController.updatedPreset(
			from: preset,
			rawTitle: "   ",
			rawNotation: "3d6+2d4"
		)
		guard case let .success(updated) = result else {
			return XCTFail("Expected successful update")
		}
		XCTAssertEqual(updated.id, "preset-1")
		XCTAssertEqual(updated.title, "3d6+2d4")
		XCTAssertEqual(updated.notation, "3d6+2d4")
	}

	func testPresetPickerUpdatedPresetRejectsInvalidNotation() {
		let preset = DiceSavedPreset(id: "preset-2", title: "Old", notation: "1d6")
		let result = PresetPickerViewController.updatedPreset(
			from: preset,
			rawTitle: "Broken",
			rawNotation: "3x6"
		)
		guard case let .failure(error) = result else {
			return XCTFail("Expected invalid notation failure")
		}
		XCTAssertEqual(error, .invalidSegment(segment: "x", hintKey: "error.input.hint.invalidCharacter"))
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
		viewModel.applyPerDieColorSelection(.crimson, at: 1)
		XCTAssertNil(viewModel.dieColorPreset(forDieAt: 0))
		XCTAssertEqual(viewModel.dieColorPreset(forDieAt: 1), .crimson)
		XCTAssertEqual(viewModel.dieColorPreset(for: 6), .ivory)
	}

	func testViewModelPerDieColorOverrideDoesNotMutateSiblingDiceInGroupedNotation() {
		let suiteName = "DiceTests.viewmodel.diecolors.grouped-perdie.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults),
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { $0.lowerBound }, randomDouble: { 0.5 }))
		)

		_ = viewModel.rollFromInput("3d6(red)+2d6(blue)")
		viewModel.applyPerDieColorSelection(.amber, at: 0)

		XCTAssertEqual(viewModel.dieColorPreset(forDieAt: 0), .amber)
		XCTAssertEqual(viewModel.dieColorPreset(forDieAt: 1), .crimson)
		XCTAssertEqual(viewModel.dieColorPreset(forDieAt: 2), .crimson)
		XCTAssertEqual(viewModel.dieColorPreset(forDieAt: 3), .sapphire)
		XCTAssertEqual(viewModel.dieColorPreset(forDieAt: 4), .sapphire)
		XCTAssertEqual(viewModel.dieColorPreset(for: 6), .ivory)
	}

	func testViewModelPerDieColorSelectionSplitsOnlyTargetedDieFromColorTaggedGroup() {
		let suiteName = "DiceTests.viewmodel.diecolors.split-group.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults),
			rollSession: DiceRollSession(intuitiveRoller: IntuitiveRoller(fallbackRoller: TrueRandomRoller { $0.lowerBound }, randomDouble: { 0.5 }))
		)

		_ = viewModel.rollFromInput("4d6(red)")
		viewModel.applyPerDieColorSelection(.sapphire, at: 1)

		XCTAssertEqual(viewModel.configuration.notation, "1d6(red)+1d6(blue)+2d6(red)")
		XCTAssertEqual(viewModel.configuration.perDieColorTags, ["red", "blue", "red", "red"])
		XCTAssertEqual(viewModel.dieColorPreset(forDieAt: 0), .crimson)
		XCTAssertEqual(viewModel.dieColorPreset(forDieAt: 1), .sapphire)
		XCTAssertEqual(viewModel.dieColorPreset(forDieAt: 2), .crimson)
		XCTAssertEqual(viewModel.dieColorPreset(forDieAt: 3), .crimson)
	}

	func testViewModelRollFromInputAppliesNotationColorOverridesPerDie() {
		let suiteName = "DiceTests.viewmodel.diecolors.notation.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let viewModel = DiceViewModel(
			preferencesStore: DicePreferencesStore(defaults: defaults),
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		_ = viewModel.rollFromInput("2d6(red)+d6(blue)")
		XCTAssertEqual(viewModel.dieColorPreset(forDieAt: 0), .crimson)
		XCTAssertEqual(viewModel.dieColorPreset(forDieAt: 1), .crimson)
		XCTAssertEqual(viewModel.dieColorPreset(forDieAt: 2), .sapphire)
	}

	func testViewModelRestoreAppliesNotationColorOverridesAndDiceCountBeforeFirstRoll() {
		let suiteName = "DiceTests.viewmodel.restore.notationcolors.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferencesStore = DicePreferencesStore(defaults: defaults)
		preferencesStore.save(
			DiceUserPreferences(
				lastNotation: "2d6(red)+1d6(blue)",
				recentPresets: []
			)
		)
		let viewModel = DiceViewModel(
			preferencesStore: preferencesStore,
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		viewModel.restore()

		XCTAssertEqual(viewModel.diceSideCounts, [6, 6, 6])
		XCTAssertEqual(viewModel.diceValues.count, 3)
		XCTAssertEqual(viewModel.dieColorPreset(forDieAt: 0), .crimson)
		XCTAssertEqual(viewModel.dieColorPreset(forDieAt: 1), .crimson)
		XCTAssertEqual(viewModel.dieColorPreset(forDieAt: 2), .sapphire)
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
		viewModel.setD6PipStyle(.square)
		XCTAssertEqual(viewModel.d6PipStyle, .square)
		XCTAssertEqual(preferencesStore.load().d6PipStyle, .square)
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
		viewModel.setD6PipStyle(.square)
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
		let matte = SCNMaterial()
		let gloss = SCNMaterial()
		let stone = SCNMaterial()
		DiceDieFinish.matte.apply(to: matte)
		DiceDieFinish.gloss.apply(to: gloss)
		DiceDieFinish.stone.apply(to: stone, baseColor: .red, dieIndex: 7)

		let matteSurface = matte.shaderModifiers?[.surface]
		XCTAssertNotNil(matteSurface)
		XCTAssertTrue(matteSurface?.contains("dfdx(fillMask)") == true)
		XCTAssertEqual(gloss.lightingModel, .blinn)
		XCTAssertNotNil(gloss.shaderModifiers?[.surface])
		XCTAssertEqual(stone.lightingModel, .lambert)
		XCTAssertGreaterThan(gloss.shininess, stone.shininess)
		let stoneSurface = stone.shaderModifiers?[.surface]
		XCTAssertNotNil(stoneSurface)
		XCTAssertEqual(stone.shininess, 0.2007, accuracy: 0.00001)
		XCTAssertTrue(stoneSurface?.contains("simplexNoise3D") == true)
		XCTAssertTrue(stoneSurface?.contains("scn_frame.inverseViewTransform") == true)
		XCTAssertTrue(stoneSurface?.contains("scn_node.inverseModelTransform") == true)
		XCTAssertTrue(stoneSurface?.contains("_surface.shininess - 0.20") == true)
		XCTAssertTrue(stoneSurface?.contains("0.7071068") == true)
		XCTAssertTrue(stoneSurface?.contains("_surface.position.xyz") == true)
		XCTAssertTrue(stoneSurface?.contains("(p.x + p.y + p.z)") == true)
		XCTAssertTrue(stoneSurface?.contains("float3 originalDiffuse") == true)
		XCTAssertTrue(stoneSurface?.contains("float3 contrastColor") == true)
		XCTAssertTrue(stoneSurface?.contains("mix(mainColor, contrastColor, marblePattern)") == true)
		XCTAssertTrue(stoneSurface?.contains("symbolMask") == true)
		XCTAssertTrue(stoneSurface?.contains("symbolMaskFromMetalness") == true)
		XCTAssertTrue(stoneSurface?.contains("* 4096.0") == true)
		XCTAssertTrue(stoneSurface?.contains("dfdx(fillMask)") == true)
	}

	func testStoneFinishShaderRendersNeutralMarbleVariation() {
		let scene = SCNScene()
		let camera = SCNCamera()
		camera.usesOrthographicProjection = true
		camera.orthographicScale = 1.25
		let cameraNode = SCNNode()
		cameraNode.camera = camera
		cameraNode.position = SCNVector3(0, 0, 4)
		scene.rootNode.addChildNode(cameraNode)

		let light = SCNLight()
		light.type = .omni
		light.intensity = 1200
		let lightNode = SCNNode()
		lightNode.light = light
		lightNode.position = SCNVector3(1.5, 1.8, 2.8)
		scene.rootNode.addChildNode(lightNode)

		let geometry = SCNBox(width: 1.7, height: 1.7, length: 1.7, chamferRadius: 0.18)
		let material = SCNMaterial()
		material.diffuse.contents = UIColor.white
		DiceDieFinish.stone.apply(to: material, baseColor: .white, dieIndex: 1)
		geometry.materials = [material]
		scene.rootNode.addChildNode(SCNNode(geometry: geometry))

		let renderer = SCNRenderer(device: nil, options: nil)
		renderer.scene = scene
		renderer.pointOfView = cameraNode
		let image = renderer.snapshot(atTime: 0, with: CGSize(width: 160, height: 160), antialiasingMode: .none)

		guard let stats = pixelStats(in: image, sampleRect: CGRect(x: 50, y: 50, width: 60, height: 60)) else {
			XCTFail("Expected readable pixel stats from stone finish snapshot")
			return
		}

		XCTAssertGreaterThan(stats.luminanceStdDev, 0.012)
		XCTAssertLessThan(abs(stats.meanR - stats.meanG), 0.15)
		XCTAssertLessThan(abs(stats.meanG - stats.meanB), 0.15)
	}

	func testBoardRenderLayoutReturnsCenterForEveryDieWithinBounds() {
		let bounds = CGRect(x: 0, y: 0, width: 720, height: 520)
		let layout = DiceCollectionViewController.boardRenderLayout(
			itemCount: 8,
			bounds: bounds,
			layoutPreset: .spacious,
			mixed: true
		)
		XCTAssertEqual(layout.centers.count, 8)
		XCTAssertGreaterThan(layout.sideLength, 0)
		for center in layout.centers {
			XCTAssertGreaterThanOrEqual(center.x, bounds.minX)
			XCTAssertLessThanOrEqual(center.x, bounds.maxX)
			XCTAssertGreaterThanOrEqual(center.y, bounds.minY)
			XCTAssertLessThanOrEqual(center.y, bounds.maxY)
		}
	}

	func testBoardRenderLayoutHandlesMixedDiceAtV1UpperBound() {
		let bounds = CGRect(x: 0, y: 0, width: 1180, height: 760)
		let layout = DiceCollectionViewController.boardRenderLayout(
			itemCount: 30,
			bounds: bounds,
			layoutPreset: .compact,
			mixed: true
		)

		XCTAssertEqual(layout.centers.count, 30)
		XCTAssertGreaterThan(layout.sideLength, 0)
		for center in layout.centers {
			XCTAssertGreaterThanOrEqual(center.x, bounds.minX)
			XCTAssertLessThanOrEqual(center.x, bounds.maxX)
			XCTAssertGreaterThanOrEqual(center.y, bounds.minY)
			XCTAssertLessThanOrEqual(center.y, bounds.maxY)
		}
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
		XCTAssertEqual(texture.size.width, 512, accuracy: 0.1)
		XCTAssertEqual(texture.size.height, 512, accuracy: 0.1)
	}

	func testD6OutlineMaskDoesNotCoverPipCenters() {
		let textureSet = D6SceneKitRenderConfig.faceTextureSet(value: 6, fillColor: .white, pipStyle: .round)
		guard let width = textureSet.roughness.cgImage?.width else {
			XCTFail("Expected roughness mask cgImage")
			return
		}
		let pipCenterX = Int((Double(width) * 0.28).rounded())
		let pipCenterY = Int((Double(width) * 0.28).rounded())
		let radius = Double(width) * 0.08
		let outlineWidth = radius * 0.20
		let ringProbeX = Int((Double(pipCenterX) + radius + (outlineWidth * 0.5)).rounded())
		guard
			let fillCenter = grayscalePixel(in: textureSet.roughness, x: pipCenterX, y: pipCenterY),
			let outlineCenter = grayscalePixel(in: textureSet.metalness, x: pipCenterX, y: pipCenterY),
			let outlineRing = grayscalePixel(in: textureSet.metalness, x: ringProbeX, y: pipCenterY)
		else {
			XCTFail("Expected readable D6 symbol masks")
			return
		}

		XCTAssertGreaterThan(fillCenter, 240, "Pip center should belong to the fill mask")
		XCTAssertLessThan(outlineCenter, 16, "Pip center should not be included in outline mask")
		XCTAssertGreaterThan(outlineRing, 32, "Outline mask should contain the outer ring")
	}

	func testD6PipStylesGenerateDistinctTexturesForSameFaceValue() {
		let round = D6SceneKitRenderConfig.faceTexture(value: 5, pipStyle: .round)
		let square = D6SceneKitRenderConfig.faceTexture(value: 5, pipStyle: .square)

		let roundData = round.pngData()
		let squareData = square.pngData()

		XCTAssertNotNil(roundData)
		XCTAssertNotNil(squareData)
		XCTAssertNotEqual(roundData, squareData)
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

	func testD6FaceTextureSetReusesCachedMapsForSameInputs() {
		let fillColor = UIColor(red: 0.72, green: 0.14, blue: 0.22, alpha: 1.0)
		let first = D6SceneKitRenderConfig.faceTextureSet(value: 4, fillColor: fillColor, pipStyle: .round)
		let second = D6SceneKitRenderConfig.faceTextureSet(value: 4, fillColor: fillColor, pipStyle: .round)

		XCTAssertTrue(first.diffuse === second.diffuse)
		XCTAssertTrue(first.normal === second.normal)
		XCTAssertTrue(first.metalness === second.metalness)
		XCTAssertTrue(first.roughness === second.roughness)
	}

	func testD6FaceTextureSetCacheSeparatesDistinctStylesAndColors() {
		let red = UIColor(red: 0.72, green: 0.14, blue: 0.22, alpha: 1.0)
		let blue = UIColor(red: 0.14, green: 0.24, blue: 0.72, alpha: 1.0)

		let roundRed = D6SceneKitRenderConfig.faceTextureSet(value: 5, fillColor: red, pipStyle: .round)
		let squareRed = D6SceneKitRenderConfig.faceTextureSet(value: 5, fillColor: red, pipStyle: .square)
		let roundBlue = D6SceneKitRenderConfig.faceTextureSet(value: 5, fillColor: blue, pipStyle: .round)

		XCTAssertFalse(roundRed.diffuse === squareRed.diffuse)
		XCTAssertFalse(roundRed.diffuse === roundBlue.diffuse)
	}

	func testD6FlatNormalMapImageIsSharedTexture() {
		let first = D6SceneKitRenderConfig.flatNormalMapImage()
		let second = D6SceneKitRenderConfig.flatNormalMapImage()
		XCTAssertTrue(first === second)
	}

	func testUnsupportedSideCountUsesRoundedRectGeometryFallback() {
		let summary = DiceCubeView.debugGeometrySummary(sideCount: 5)
		XCTAssertEqual(summary.typeName, "SCNBox")
		XCTAssertEqual(summary.materialCount, 6)
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

	func testFaceNumeralFontOptionsExcludeDyslexiaFriendlyEntry() {
		let keys = Set(DiceFaceNumeralFont.allCases.map(\.menuTitleKey))
		XCTAssertFalse(keys.contains("font.dyslexiaFriendly"))
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

	func testControllerExposesMainScreenStatsButton() {
		let controller = DiceCollectionViewController(collectionViewLayout: UICollectionViewFlowLayout())
		controller.loadViewIfNeeded()
		let statsButton = findView(in: controller.view, accessibilityIdentifier: "statsButton")
		XCTAssertNotNil(statsButton)
	}

	func testDieIndexFromAccessibilityIdentifierParsesExpectedFormat() {
		XCTAssertEqual(DiceCollectionViewController.dieIndexFromAccessibilityIdentifier("dieButton_0"), 0)
		XCTAssertEqual(DiceCollectionViewController.dieIndexFromAccessibilityIdentifier("dieButton_12"), 12)
	}

	private func findView(in root: UIView, accessibilityIdentifier: String) -> UIView? {
		if root.accessibilityIdentifier == accessibilityIdentifier {
			return root
		}
		for subview in root.subviews {
			if let match = findView(in: subview, accessibilityIdentifier: accessibilityIdentifier) {
				return match
			}
		}
		return nil
	}

	func testDieIndexFromAccessibilityIdentifierRejectsInvalidValues() {
		XCTAssertNil(DiceCollectionViewController.dieIndexFromAccessibilityIdentifier(nil))
		XCTAssertNil(DiceCollectionViewController.dieIndexFromAccessibilityIdentifier("die_2"))
		XCTAssertNil(DiceCollectionViewController.dieIndexFromAccessibilityIdentifier("dieButton_"))
		XCTAssertNil(DiceCollectionViewController.dieIndexFromAccessibilityIdentifier("dieButton_x"))
	}

	func testDiceCellExpandedHitBoundsGrowsByPadding() {
		let bounds = CGRect(x: 0, y: 0, width: 100, height: 80)
		let expanded = DiceCollectionViewCell.expandedHitBounds(for: bounds, padding: 10)
		XCTAssertEqual(expanded.origin.x, -10, accuracy: 0.001)
		XCTAssertEqual(expanded.origin.y, -10, accuracy: 0.001)
		XCTAssertEqual(expanded.size.width, 120, accuracy: 0.001)
		XCTAssertEqual(expanded.size.height, 100, accuracy: 0.001)
	}

	func testBoardAnimationLockedIndicesUsesPersistentLocksWhenNoAnimationSubsetProvided() {
		let locked = DiceCollectionViewController.boardAnimationLockedIndices(
			totalDice: 5,
			persistentLocked: [1, 4],
			animatingIndices: nil
		)
		XCTAssertEqual(locked, Set([1, 4]))
	}

	func testBoardAnimationLockedIndicesFreezesNonTargetDiceForSingleDieAnimation() {
		let locked = DiceCollectionViewController.boardAnimationLockedIndices(
			totalDice: 5,
			persistentLocked: [1],
			animatingIndices: [3]
		)
		XCTAssertEqual(locked, Set([0, 1, 2, 4]))
	}

	func testDiceCellConstraintsInvolvingButtonFiltersOnlyRelatedConstraints() {
		let button = UIButton(type: .system)
		let container = UIView()
		let other = UIView()
		button.translatesAutoresizingMaskIntoConstraints = false
		other.translatesAutoresizingMaskIntoConstraints = false
		container.addSubview(button)
		container.addSubview(other)

		let buttonCenterX = button.centerXAnchor.constraint(equalTo: container.centerXAnchor)
		let buttonCenterY = button.centerYAnchor.constraint(equalTo: container.centerYAnchor)
		let unrelated = other.leadingAnchor.constraint(equalTo: container.leadingAnchor)

		let filtered = DiceCollectionViewCell.constraintsInvolvingButton(
			button,
			cellConstraints: [buttonCenterX, unrelated],
			contentConstraints: [buttonCenterY]
		)

		XCTAssertEqual(filtered.count, 2)
		XCTAssertTrue(filtered.contains(buttonCenterX))
		XCTAssertTrue(filtered.contains(buttonCenterY))
		XCTAssertFalse(filtered.contains(unrelated))
	}

	func testGraphPointsProvideAllFacesAndCounts() {
		let points = DiceRollDistributionChartData.points(from: [0, 2, 4])
		XCTAssertEqual(points, [
			DiceRollDistributionPoint(face: 1, count: 0),
			DiceRollDistributionPoint(face: 2, count: 2),
			DiceRollDistributionPoint(face: 3, count: 4),
		])
	}

	func testGraphPointsAreEmptyWhenNoBinsPresent() {
		let points = DiceRollDistributionChartData.points(from: [])
		XCTAssertTrue(points.isEmpty)
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

	func testDiceCubeViewUsesUniqueGeometryInstancesPerDie() {
		XCTAssertTrue(DiceCubeView.debugUsesUniqueGeometryPerDie(sideCount: 6))
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
		for faceLabels in labels {
			XCTAssertEqual(faceLabels.count, 3)
			XCTAssertEqual(Set(faceLabels).count, 3)
			XCTAssertTrue(faceLabels.allSatisfy { (1...4).contains($0) })
		}
	}

	func testD4OrderedFaceLabelsPreserveVerticesWithStableCornerOrdering() {
		let unordered = DiceCubeView.debugD4FaceVertexLabels()
		let ordered = DiceCubeView.debugD4OrderedFaceVertexLabels()
		XCTAssertEqual(unordered.count, ordered.count)

		var changedAtLeastOneFace = false
		for index in ordered.indices {
			XCTAssertEqual(Set(unordered[index]), Set(ordered[index]))
			if unordered[index] != ordered[index] {
				changedAtLeastOneFace = true
			}
		}
		XCTAssertTrue(changedAtLeastOneFace)
	}

	func testD4MaterialFaceLabelsMatchOrderedCornerMapping() {
		let ordered = DiceCubeView.debugD4OrderedFaceVertexLabels()
		let material = DiceCubeView.debugD4MaterialFaceVertexLabels()
		XCTAssertEqual(material, ordered)
	}

	func testD4MaterialFaceLabelsMatchBuiltGeometryCornerMapping() {
		let geometry = DiceCubeView.debugD4GeometryFaceVertexLabels()
		let material = DiceCubeView.debugD4MaterialFaceVertexLabels()
		XCTAssertEqual(material, geometry)
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

	private struct PixelStats {
		let meanR: Double
		let meanG: Double
		let meanB: Double
		let luminanceStdDev: Double
	}

	private func pixelStats(in image: UIImage, sampleRect: CGRect) -> PixelStats? {
		guard let cgImage = image.cgImage else { return nil }
		let width = cgImage.width
		let height = cgImage.height
		guard width > 0, height > 0 else { return nil }

		let bytesPerPixel = 4
		let bytesPerRow = bytesPerPixel * width
		var pixels = Array(repeating: UInt8(0), count: bytesPerRow * height)
		guard let context = CGContext(
			data: &pixels,
			width: width,
			height: height,
			bitsPerComponent: 8,
			bytesPerRow: bytesPerRow,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else { return nil }
		context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

		let sx = max(0, Int(sampleRect.minX))
		let sy = max(0, Int(sampleRect.minY))
		let ex = min(width, Int(sampleRect.maxX))
		let ey = min(height, Int(sampleRect.maxY))
		guard sx < ex, sy < ey else { return nil }

		var sumR = 0.0
		var sumG = 0.0
		var sumB = 0.0
		var luminances: [Double] = []
		luminances.reserveCapacity((ex - sx) * (ey - sy))

		for y in sy..<ey {
			for x in sx..<ex {
				let offset = y * bytesPerRow + x * bytesPerPixel
				let r = Double(pixels[offset]) / 255.0
				let g = Double(pixels[offset + 1]) / 255.0
				let b = Double(pixels[offset + 2]) / 255.0
				sumR += r
				sumG += g
				sumB += b
				luminances.append((0.2126 * r) + (0.7152 * g) + (0.0722 * b))
			}
		}

		let count = Double(luminances.count)
		guard count > 0 else { return nil }
		let meanR = sumR / count
		let meanG = sumG / count
		let meanB = sumB / count
		let meanL = luminances.reduce(0, +) / count
		let variance = luminances.reduce(0) { partial, value in
			let delta = value - meanL
			return partial + (delta * delta)
		} / count
		return PixelStats(meanR: meanR, meanG: meanG, meanB: meanB, luminanceStdDev: sqrt(variance))
	}

	private func grayscalePixel(in image: UIImage, x: Int, y: Int) -> UInt8? {
		guard let cgImage = image.cgImage else { return nil }
		let width = cgImage.width
		let height = cgImage.height
		guard width > 0, height > 0, x >= 0, y >= 0, x < width, y < height else { return nil }

		let bytesPerPixel = 4
		let bytesPerRow = bytesPerPixel * width
		var pixels = Array(repeating: UInt8(0), count: bytesPerRow * height)
		guard let context = CGContext(
			data: &pixels,
			width: width,
			height: height,
			bitsPerComponent: 8,
			bytesPerRow: bytesPerRow,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else { return nil }
		context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
		let offset = y * bytesPerRow + x * bytesPerPixel
		return pixels[offset]
	}

}
