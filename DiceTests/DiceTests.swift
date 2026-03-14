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

	func testPreferencesStoreDefaultsLightingAngleToNaturalWhenUnset() {
		let suiteName = "DiceTests.defaults.lighting.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = DicePreferencesStore(defaults: defaults)

		let loaded = store.load()
		XCTAssertEqual(loaded.lightingAngle, .natural)
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
			lightingAngle: .fixed,
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
		let formatted = viewModel.formattedTotalsText(outcome: outcome)
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
		viewModel.setTableTexture(.black)
		XCTAssertEqual(viewModel.tableTexture, .black)
		XCTAssertEqual(preferencesStore.load().tableTexture, .black)
	}

	func testViewModelThemeSwitchDoesNotMutateBlackTextureSelection() {
		let suiteName = "DiceTests.viewmodel.texture.theme.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferencesStore = DicePreferencesStore(defaults: defaults)
		let viewModel = DiceViewModel(
			preferencesStore: preferencesStore,
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		viewModel.setTableTexture(.black)
		viewModel.setTheme(.lightMode)
		viewModel.setTheme(.darkMode)

		XCTAssertEqual(viewModel.tableTexture, .black)
		XCTAssertEqual(preferencesStore.load().tableTexture, .black)
	}

	func testViewModelLightingAngleSelectionPersistsToPreferences() {
		let suiteName = "DiceTests.viewmodel.lighting.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferencesStore = DicePreferencesStore(defaults: defaults)
		let viewModel = DiceViewModel(
			preferencesStore: preferencesStore,
			historyStore: DiceRollHistoryStore(defaults: defaults)
		)

		XCTAssertEqual(viewModel.lightingAngle, .natural)
		viewModel.setLightingAngle(.fixed)
		XCTAssertEqual(viewModel.lightingAngle, .fixed)
		XCTAssertEqual(preferencesStore.load().lightingAngle, .fixed)
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
		let layout = DiceViewController.boardRenderLayout(
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
		let bounds = CGRect(x: 0, y: 0, width: 390, height: 844)
		let layout = DiceViewController.boardRenderLayout(
			itemCount: 30,
			bounds: bounds,
			layoutPreset: .compact,
			mixed: true
		)

		XCTAssertEqual(layout.centers.count, 30)
		let readableFloor = DiceViewController.readableBoardSideLengthFloor(layoutPreset: .compact, mixed: true)
		XCTAssertGreaterThanOrEqual(layout.sideLength + 0.001, readableFloor)
		for center in layout.centers {
			XCTAssertGreaterThanOrEqual(center.x, bounds.minX)
			XCTAssertLessThanOrEqual(center.x, bounds.maxX)
		}
		let maxY = layout.centers.map(\.y).max() ?? bounds.minY
		XCTAssertGreaterThan(maxY, bounds.maxY, "High dice counts should overflow vertically instead of shrinking below readable size")
	}

	func testBoardRenderLayoutUsesThreeColumnReadableFloorOnReferencePhoneWidth() {
		let bounds = CGRect(x: 0, y: 0, width: 390, height: 844)
		let layout = DiceViewController.boardRenderLayout(
			itemCount: 24,
			bounds: bounds,
			layoutPreset: .compact,
			mixed: true
		)
		let floor = DiceViewController.readableBoardSideLengthFloor(layoutPreset: .compact, mixed: true)
		XCTAssertGreaterThanOrEqual(layout.sideLength + 0.001, floor)
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

		_ = viewModel.rollFromInput("3d6+2d4+d20")
		let outcome = viewModel.rollCurrent()
		let text = viewModel.formattedTotalsText(outcome: outcome)

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

		_ = viewModel.rollFromInput("2d6i")
		let outcome = viewModel.rollCurrent()
		let text = viewModel.formattedTotalsText(outcome: outcome)

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

		_ = viewModel.rollFromInput("1d6+1d100")
		let outcome = viewModel.rollCurrent()
		let text = viewModel.formattedTotalsText(outcome: outcome)

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

		_ = viewModel.rollFromInput("1d30+1d100")
		let outcome = viewModel.rollCurrent()
		let text = viewModel.formattedTotalsText(outcome: outcome)

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
		XCTAssertEqual(viewModel.statusText(rollCount: 1), "d6 • Rolls 1")
		viewModel.toggleMode()
		XCTAssertEqual(viewModel.statusText(rollCount: 4), "d6 • Rolls 4")
	}

	func testWatchRollViewModelStatusTextUsesGlanceableTokensWithLastValue() {
		let viewModel = WatchRollViewModel()
		XCTAssertEqual(viewModel.statusText(lastValue: 5), "d6 • Result 5")
		viewModel.toggleMode()
		XCTAssertEqual(viewModel.statusText(lastValue: 2), "d6 • Result 2")
	}

	func testWatchRollViewModelUsesConfiguredSideCountForNotationAndRolls() {
		let viewModel = WatchRollViewModel(
			rollSession: DiceRollSession(
				intuitiveRoller: IntuitiveRoller(
					fallbackRoller: TrueRandomRoller { range in range.upperBound },
					randomDouble: { 0.5 }
				)
			)
		)

		viewModel.setSideCount(20)
		XCTAssertEqual(viewModel.currentNotation, "1d20")
		let outcome = viewModel.roll()
		XCTAssertEqual(outcome.sideCounts, [20])
		XCTAssertEqual(outcome.values, [20])
	}

	func testWatchRollViewModelClampsSideCountToSupportedRange() {
		let viewModel = WatchRollViewModel()
		viewModel.setSideCount(1)
		XCTAssertEqual(viewModel.sideCount, 2)
		XCTAssertEqual(viewModel.currentNotation, "1d2")

		viewModel.setSideCount(200)
		XCTAssertEqual(viewModel.sideCount, 100)
		XCTAssertEqual(viewModel.currentNotation, "1d100")
	}

	func testWatchRollViewModelSideCountSwitchResetsRepeatConfigurationRange() {
		var requestedRanges: [ClosedRange<Int>] = []
		let deterministic = TrueRandomRoller { range in
			requestedRanges.append(range)
			return range.lowerBound
		}
		let session = DiceRollSession(
			intuitiveRoller: IntuitiveRoller(
				fallbackRoller: deterministic,
				randomDouble: { 0.5 }
			)
		)
		let viewModel = WatchRollViewModel(rollSession: session, isIntuitiveMode: false, sideCount: 6)

		_ = viewModel.roll()
		viewModel.setSideCount(21)
		_ = viewModel.repeatLastRoll()

		XCTAssertEqual(requestedRanges, [1...6, 1...21])
		XCTAssertEqual(viewModel.currentNotation, "1d21")
	}

	func testWatchRollViewModelRerollBurstStaysWithinInteractionBudget() {
		let deterministic = TrueRandomRoller { range in range.lowerBound }
		let session = DiceRollSession(
			intuitiveRoller: IntuitiveRoller(
				fallbackRoller: deterministic,
				randomDouble: { 0.5 }
			)
		)
		let viewModel = WatchRollViewModel(rollSession: session, isIntuitiveMode: false, sideCount: 20)
		_ = viewModel.roll()

		let start = CFAbsoluteTimeGetCurrent()
		for _ in 0..<200 {
			_ = viewModel.repeatLastRoll()
		}
		let elapsed = CFAbsoluteTimeGetCurrent() - start
		XCTAssertLessThan(elapsed, 1.0, "Expected 200 watch rerolls to stay under a 1s model budget.")
	}

	func testWatchAccessibilityFormatterUsesSideAwareValueStrings() {
		XCTAssertEqual(WatchAccessibilityFormatter.dieValue(value: 17, sideCount: 21), "Value 17 on d21")
		XCTAssertEqual(WatchAccessibilityFormatter.dieValue(value: 2, sideCount: 2), "Value 2 on d2")
	}

	func testWatchAccessibilityFormatterProvidesStableControlLabels() {
		XCTAssertEqual(WatchAccessibilityFormatter.rollButtonLabel, "Roll dice")
		XCTAssertEqual(WatchAccessibilityFormatter.rollButtonHint, "Double tap to roll one die")
		XCTAssertEqual(WatchAccessibilityFormatter.latestResultLabel, "Latest die result")
		XCTAssertEqual(WatchAccessibilityFormatter.scenePreviewLabel, "Latest die result, 3D preview")
	}

	func testWatchSingleDieConfigurationStoreRoundTrip() {
		let suiteName = "DiceTests.watch.config.store.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = WatchSingleDieConfigurationStore(defaults: defaults)
		let expected = WatchSingleDieConfiguration(
			sideCount: 20,
			colorTag: "blue",
			isIntuitiveMode: true,
			backgroundTexture: "felt",
			updatedAt: Date(timeIntervalSince1970: 1234)
		)

		store.save(expected)

		XCTAssertEqual(store.load(), expected)
	}

	func testWatchSingleDieConfigurationUsesBlackForWatchSeedWithoutChangingGeneralDefault() {
		XCTAssertEqual(WatchSingleDieConfiguration.watchDefault.backgroundTexture, "black")
		XCTAssertEqual(WatchSingleDieConfiguration().backgroundTexture, "neutral")
	}

	func testWatchSingleDieConfigurationConflictResolverPrefersNewerTimestamp() {
		let local = WatchSingleDieConfiguration(
			sideCount: 6,
			colorTag: "ivory",
			isIntuitiveMode: false,
			backgroundTexture: "neutral",
			updatedAt: Date(timeIntervalSince1970: 10)
		)
		let remote = WatchSingleDieConfiguration(
			sideCount: 12,
			colorTag: "red",
			isIntuitiveMode: true,
			backgroundTexture: "wood",
			updatedAt: Date(timeIntervalSince1970: 20)
		)

		let resolved = WatchSingleDieConfigurationConflictResolver.resolve(local: local, remote: remote)

		XCTAssertEqual(resolved, remote)
	}

	func testWatchSingleDieConfigurationConflictResolverUsesRemoteOnTimestampTie() {
		let stamp = Date(timeIntervalSince1970: 42)
		let local = WatchSingleDieConfiguration(
			sideCount: 6,
			colorTag: "ivory",
			isIntuitiveMode: false,
			backgroundTexture: "neutral",
			updatedAt: stamp
		)
		let remote = WatchSingleDieConfiguration(
			sideCount: 8,
			colorTag: "green",
			isIntuitiveMode: true,
			backgroundTexture: "felt",
			updatedAt: stamp
		)

		let resolved = WatchSingleDieConfigurationConflictResolver.resolve(local: local, remote: remote)

		XCTAssertEqual(resolved, remote)
	}

	func testWatchSyncBridgeDoesNotOverwriteNewerRemoteWhenPhoneProjectionIsUnchanged() {
		let suiteName = "DiceTests.watch.config.bridge.nooverwrite.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let bridge = WatchSingleDieConfigurationSyncBridge(
			store: WatchSingleDieConfigurationStore(defaults: defaults)
		)

		let phoneProjection = WatchSingleDieConfiguration(
			sideCount: 6,
			colorTag: "ivory",
			isIntuitiveMode: false,
			backgroundTexture: "neutral",
			updatedAt: Date(timeIntervalSince1970: 10)
		)
		bridge.applyPhoneSnapshotIfChanged(phoneProjection)

		let newerRemote = WatchSingleDieConfiguration(
			sideCount: 20,
			colorTag: "blue",
			isIntuitiveMode: true,
			backgroundTexture: "black",
			updatedAt: Date(timeIntervalSince1970: 20)
		)
		_ = bridge.applyRemoteConfiguration(newerRemote)
		bridge.applyPhoneSnapshotIfChanged(phoneProjection)

		let current = bridge.currentConfiguration()
		XCTAssertEqual(current.sideCount, 20)
		XCTAssertEqual(current.colorTag, "blue")
		XCTAssertTrue(current.isIntuitiveMode)
		XCTAssertEqual(current.backgroundTexture, "black")
		XCTAssertEqual(current.updatedAt, Date(timeIntervalSince1970: 20))
	}

	func testWatchSyncBridgeAppliesPhoneProjectionWhenPhonePreferencesChange() {
		let suiteName = "DiceTests.watch.config.bridge.changed.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let bridge = WatchSingleDieConfigurationSyncBridge(
			store: WatchSingleDieConfigurationStore(defaults: defaults)
		)

		let initialPhoneProjection = WatchSingleDieConfiguration(
			sideCount: 6,
			colorTag: "ivory",
			isIntuitiveMode: false,
			backgroundTexture: "neutral",
			updatedAt: Date(timeIntervalSince1970: 10)
		)
		bridge.applyPhoneSnapshotIfChanged(initialPhoneProjection)

		let remote = WatchSingleDieConfiguration(
			sideCount: 20,
			colorTag: "blue",
			isIntuitiveMode: true,
			backgroundTexture: "black",
			updatedAt: Date(timeIntervalSince1970: 20)
		)
		_ = bridge.applyRemoteConfiguration(remote)

		let changedPhoneProjection = WatchSingleDieConfiguration(
			sideCount: 12,
			colorTag: "amber",
			isIntuitiveMode: false,
			backgroundTexture: "wood",
			updatedAt: Date(timeIntervalSince1970: 30)
		)
		bridge.applyPhoneSnapshotIfChanged(changedPhoneProjection)

		let current = bridge.currentConfiguration()
		XCTAssertEqual(current.sideCount, 12)
		XCTAssertEqual(current.colorTag, "amber")
		XCTAssertFalse(current.isIntuitiveMode)
		XCTAssertEqual(current.backgroundTexture, "wood")
		XCTAssertEqual(current.updatedAt, Date(timeIntervalSince1970: 30))
	}

	func testWatchSyncBridgeLocalCustomizationEditAdvancesTimestampAndWinsOverOlderRemote() {
		let suiteName = "DiceTests.watch.config.bridge.localwins.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let bridge = WatchSingleDieConfigurationSyncBridge(
			store: WatchSingleDieConfigurationStore(defaults: defaults)
		)

		let baseline = WatchSingleDieConfiguration(
			sideCount: 6,
			colorTag: "ivory",
			isIntuitiveMode: false,
			backgroundTexture: "black",
			updatedAt: Date(timeIntervalSince1970: 10)
		)
		_ = bridge.applyRemoteConfiguration(baseline)
		let baselineTimestamp = bridge.currentConfiguration().updatedAt

		bridge.updateLocalConfiguration { configuration in
			configuration.sideCount = 20
			configuration.colorTag = "blue"
			configuration.isIntuitiveMode = true
			configuration.backgroundTexture = "wood"
		}

		let locallyEdited = bridge.currentConfiguration()
		XCTAssertGreaterThan(locallyEdited.updatedAt, baselineTimestamp)
		XCTAssertEqual(locallyEdited.sideCount, 20)
		XCTAssertEqual(locallyEdited.colorTag, "blue")
		XCTAssertTrue(locallyEdited.isIntuitiveMode)
		XCTAssertEqual(locallyEdited.backgroundTexture, "wood")

		let staleRemote = WatchSingleDieConfiguration(
			sideCount: 4,
			colorTag: "red",
			isIntuitiveMode: false,
			backgroundTexture: "felt",
			updatedAt: baselineTimestamp
		)
		let resolved = bridge.applyRemoteConfiguration(staleRemote)

		XCTAssertEqual(resolved, locallyEdited)
		XCTAssertEqual(bridge.currentConfiguration(), locallyEdited)
	}

	func testWatchSyncBridgeAvoidsStaleStateAcrossRepeatedCustomizeOpenCloseCycles() {
		let suiteName = "DiceTests.watch.config.bridge.reopen.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let bridge = WatchSingleDieConfigurationSyncBridge(
			store: WatchSingleDieConfigurationStore(defaults: defaults)
		)

		let seed = WatchSingleDieConfiguration(
			sideCount: 6,
			colorTag: "ivory",
			isIntuitiveMode: false,
			backgroundTexture: "black",
			updatedAt: Date(timeIntervalSince1970: 5)
		)
		_ = bridge.applyRemoteConfiguration(seed)

		let edits: [(side: Int, color: DiceDieColorPreset, mode: Bool, background: DiceTableTexture)] = [
			(20, .emerald, true, .wood),
			(8, .amber, false, .felt),
			(12, .sapphire, true, .black),
		]

		var expected = seed
		for edit in edits {
			let openedConfiguration = bridge.currentConfiguration()
			XCTAssertEqual(openedConfiguration.sideCount, expected.sideCount)
			XCTAssertEqual(openedConfiguration.colorTag, expected.colorTag)
			XCTAssertEqual(openedConfiguration.isIntuitiveMode, expected.isIntuitiveMode)
			XCTAssertEqual(openedConfiguration.backgroundTexture, expected.backgroundTexture)

			var state = WatchSingleDieCustomizationState(configuration: openedConfiguration)
			state.setSideCount(edit.side)
			state.colorPreset = edit.color
			if state.isIntuitiveMode != edit.mode {
				state.toggleMode()
			}
			while state.backgroundTexture != edit.background {
				state.cycleBackgroundForward()
			}
			bridge.updateLocalConfiguration { configuration in
				state.apply(to: &configuration)
			}

			expected = bridge.currentConfiguration()
			XCTAssertEqual(expected.sideCount, edit.side)
			XCTAssertEqual(expected.colorTag, edit.color.notationName)
			XCTAssertEqual(expected.isIntuitiveMode, edit.mode)
			XCTAssertEqual(expected.backgroundTexture, edit.background.rawValue)
		}
	}

	func testWatchSingleDieCustomizationStateLoadsFromConfiguration() {
		let configuration = WatchSingleDieConfiguration(
			sideCount: 20,
			colorTag: "green",
			isIntuitiveMode: true,
			backgroundTexture: "black",
			updatedAt: Date(timeIntervalSince1970: 99)
		)

		let state = WatchSingleDieCustomizationState(configuration: configuration)

		XCTAssertEqual(state.sideCount, 20)
		XCTAssertEqual(state.colorPreset, .emerald)
		XCTAssertTrue(state.isIntuitiveMode)
		XCTAssertEqual(state.backgroundTexture, .black)
	}

	func testWatchSingleDieCustomizationStateAppliesEditsBackToConfiguration() {
		var configuration = WatchSingleDieConfiguration(
			sideCount: 6,
			colorTag: "ivory",
			isIntuitiveMode: false,
			backgroundTexture: "black",
			updatedAt: Date(timeIntervalSince1970: 99)
		)
		var state = WatchSingleDieCustomizationState(configuration: configuration)
		state.setSideCount(37)
		state.colorPreset = .sapphire
		state.toggleMode()
		state.cycleBackgroundForward()

		state.apply(to: &configuration)

		XCTAssertEqual(configuration.sideCount, 37)
		XCTAssertEqual(configuration.colorTag, "blue")
		XCTAssertTrue(configuration.isIntuitiveMode)
		XCTAssertEqual(configuration.backgroundTexture, "felt")
	}

	func testWatchSingleDieCustomizationStateCyclesBackgroundTexturesIncludingBlack() {
		var state = WatchSingleDieCustomizationState(
			configuration: WatchSingleDieConfiguration(backgroundTexture: "black")
		)

		state.cycleBackgroundForward()
		XCTAssertEqual(state.backgroundTexture, .felt)

		state.cycleBackgroundForward()
		state.cycleBackgroundForward()
		state.cycleBackgroundForward()
		XCTAssertEqual(state.backgroundTexture, .black)
	}

	func testWatchSingleDieCustomizationStateClampsSideRangeForStepperControls() {
		var state = WatchSingleDieCustomizationState(
			configuration: WatchSingleDieConfiguration(sideCount: 6)
		)

		state.setSideCount(DiceSingleDieSceneGeometryFactory.minimumSideCount - 1)
		XCTAssertEqual(state.sideCount, DiceSingleDieSceneGeometryFactory.minimumSideCount)

		state.setSideCount(DiceSingleDieSceneGeometryFactory.maximumSideCount + 1)
		XCTAssertEqual(state.sideCount, DiceSingleDieSceneGeometryFactory.maximumSideCount)
	}

	func testWatchStoryboardBindsInterfaceControllerToTargetModule() throws {
		let projectRoot = URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent()
			.deletingLastPathComponent()
		let storyboardURL = projectRoot
			.appendingPathComponent("Dice WatchKit App")
			.appendingPathComponent("Base.lproj")
			.appendingPathComponent("Interface.storyboard")
		let source = try String(contentsOf: storyboardURL, encoding: .utf8)
		XCTAssertTrue(
			source.contains("customClass=\"InterfaceController\""),
			"Watch storyboard must reference InterfaceController for the main watch scene."
		)
		XCTAssertTrue(source.contains("customModuleProvider=\"target\""))
	}

	func testWatchStoryboardAssignsNonZeroHeightToSceneKitView() throws {
		let projectRoot = URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent()
			.deletingLastPathComponent()
		let storyboardURL = projectRoot
			.appendingPathComponent("Dice WatchKit App")
			.appendingPathComponent("Base.lproj")
			.appendingPathComponent("Interface.storyboard")
		let source = try String(contentsOf: storyboardURL, encoding: .utf8)

		let sceneTagPattern = #"<sceneKitScene[^>]*id="YvH-5M-5jF"[^>]*>"#
		let sceneTagRegex = try NSRegularExpression(pattern: sceneTagPattern)
		let wholeRange = NSRange(source.startIndex..<source.endIndex, in: source)
		guard let sceneTagMatch = sceneTagRegex.firstMatch(in: source, options: [], range: wholeRange),
			  let sceneTagRange = Range(sceneTagMatch.range, in: source) else {
			return XCTFail("Watch storyboard must contain the SceneKit scene element.")
		}

		let sceneTag = String(source[sceneTagRange])
		let heightPattern = #"height="([0-9]*\.?[0-9]+)""#
		let heightRegex = try NSRegularExpression(pattern: heightPattern)
		let sceneTagNSRange = NSRange(sceneTag.startIndex..<sceneTag.endIndex, in: sceneTag)
		guard let heightMatch = heightRegex.firstMatch(in: sceneTag, options: [], range: sceneTagNSRange),
			  let captureRange = Range(heightMatch.range(at: 1), in: sceneTag),
			  let heightValue = Double(sceneTag[captureRange]) else {
			return XCTFail("Watch storyboard SceneKit element must provide an explicit height.")
		}

		XCTAssertGreaterThan(
			heightValue,
			0.0,
			"Watch SceneKit view must have non-zero height; zero height produces a black frame."
		)
	}

	func testWatchStoryboardContainsCustomizeControllerAndActions() throws {
		let projectRoot = URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent()
			.deletingLastPathComponent()
		let storyboardURL = projectRoot
			.appendingPathComponent("Dice WatchKit App")
			.appendingPathComponent("Base.lproj")
			.appendingPathComponent("Interface.storyboard")
		let source = try String(contentsOf: storyboardURL, encoding: .utf8)

		XCTAssertTrue(source.contains("customClass=\"WatchCustomizeInterfaceController\""))
		XCTAssertTrue(source.contains("identifier=\"WatchCustomizeController\""))
		XCTAssertTrue(source.contains("selector=\"decrementSideCount\""))
		XCTAssertTrue(source.contains("selector=\"incrementSideCount\""))
		XCTAssertTrue(source.contains("selector=\"cycleColor\""))
		XCTAssertTrue(source.contains("selector=\"cycleBackground\""))
		XCTAssertTrue(source.contains("selector=\"toggleMode\""))
		XCTAssertFalse(source.contains("selector=\"closeCustomize\""))
	}

	func testWatchInterfaceControllerRegistersCustomizeEntryPoint() throws {
		let projectRoot = URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent()
			.deletingLastPathComponent()
		let controllerURL = projectRoot
			.appendingPathComponent("Dice WatchKit Extension")
			.appendingPathComponent("InterfaceController.swift")
		let source = try String(contentsOf: controllerURL, encoding: .utf8)

		XCTAssertTrue(source.contains("pushController(withName: \"WatchCustomizeController\""))
		XCTAssertTrue(source.contains("@IBAction func openCustomize()"))
	}

	func testWatchInterfaceControllerUsesLongPressMenuForCustomize() throws {
		let projectRoot = URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent()
			.deletingLastPathComponent()
		let controllerURL = projectRoot
			.appendingPathComponent("Dice WatchKit Extension")
			.appendingPathComponent("InterfaceController.swift")
		let source = try String(contentsOf: controllerURL, encoding: .utf8)

		XCTAssertTrue(source.contains("addMenuItem(with:"))
		XCTAssertTrue(source.contains("title: \"Customize\""))
		XCTAssertFalse(source.contains("optionsButton"))
	}

	func testWatchMainStoryboardUsesFullscreenDieWithoutVisibleCustomizeButton() throws {
		let projectRoot = URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent()
			.deletingLastPathComponent()
		let storyboardURL = projectRoot
			.appendingPathComponent("Dice WatchKit App")
			.appendingPathComponent("Base.lproj")
			.appendingPathComponent("Interface.storyboard")
		let source = try String(contentsOf: storyboardURL, encoding: .utf8)

		XCTAssertTrue(source.contains("selector=\"roll\""))
		XCTAssertFalse(source.contains("title=\"Customize\""))
		XCTAssertFalse(source.contains("Tap die to roll"))
		XCTAssertFalse(source.contains("selector=\"openCustomize\""))
		XCTAssertFalse(source.contains("selector=\"repeatLastRoll\""))
		XCTAssertTrue(source.contains("id=\"64x-ie-It6\""))
		XCTAssertTrue(source.contains("height=\"1\""))
	}

	func testWatchInterfaceControllerSupportsCustomizeLaunchArgumentForSimulatorSnapshots() throws {
		let projectRoot = URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent()
			.deletingLastPathComponent()
		let controllerURL = projectRoot
			.appendingPathComponent("Dice WatchKit Extension")
			.appendingPathComponent("InterfaceController.swift")
		let source = try String(contentsOf: controllerURL, encoding: .utf8)

		XCTAssertTrue(source.contains("-watchOpenCustomizeOnLaunch"))
		XCTAssertTrue(source.contains("openCustomizeIfRequestedForAutomation"))
	}

	func testWatchInterfaceControllerUsesSharedFaceTextureFactoryInsteadOfSpriteKitFaceScenes() throws {
		let projectRoot = URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent()
			.deletingLastPathComponent()
		let controllerURL = projectRoot
			.appendingPathComponent("Dice WatchKit Extension")
			.appendingPathComponent("InterfaceController.swift")
		let source = try String(contentsOf: controllerURL, encoding: .utf8)

		XCTAssertTrue(source.contains("DiceFaceTextureFactory.textureSet"))
		XCTAssertFalse(
			source.contains("SKScene(size:"),
			"Watch rendering should use the shared face texture path, not a watch-only SpriteKit face scene path."
		)
	}

	func testWatchInterfaceControllerUsesSharedTableMaterialConfigurator() throws {
		let projectRoot = URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent()
			.deletingLastPathComponent()
		let controllerURL = projectRoot
			.appendingPathComponent("Dice WatchKit Extension")
			.appendingPathComponent("InterfaceController.swift")
		let source = try String(contentsOf: controllerURL, encoding: .utf8)

		XCTAssertTrue(source.contains("DiceTableSurfaceMaterialConfigurator.configureBaseMaterial"))
		XCTAssertTrue(source.contains("DiceTableSurfaceMaterialConfigurator.applyTexture"))
	}

	func testDiceCubeViewUsesSharedFaceTextureFactoryForFaceTextures() throws {
		let projectRoot = URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent()
			.deletingLastPathComponent()
		let cubeViewURL = projectRoot
			.appendingPathComponent("Dice")
			.appendingPathComponent("DiceCubeView.swift")
		let source = try String(contentsOf: cubeViewURL, encoding: .utf8)

		XCTAssertTrue(source.contains("DiceFaceTextureFactory.textureSet"))
	}

	func testDiceCubeViewUsesSharedTableMaterialConfigurator() throws {
		let projectRoot = URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent()
			.deletingLastPathComponent()
		let cubeViewURL = projectRoot
			.appendingPathComponent("Dice")
			.appendingPathComponent("DiceCubeView.swift")
		let source = try String(contentsOf: cubeViewURL, encoding: .utf8)

		XCTAssertTrue(source.contains("DiceTableSurfaceMaterialConfigurator.configureBaseMaterial"))
		XCTAssertTrue(source.contains("DiceTableSurfaceMaterialConfigurator.applyTexture"))
	}

	func testSingleDieSceneGeometryFactorySupportsPolyhedralAndFallbackDescriptors() {
		let d20 = DiceSingleDieSceneGeometryFactory.makeDescriptor(sideCount: 20, sideLength: 96)
		XCTAssertFalse(d20.isCoin)
		XCTAssertFalse(d20.isToken)
		XCTAssertEqual(d20.faceValueCount, 20)
		XCTAssertEqual(d20.geometry.materials.count, 20)

		let d2 = DiceSingleDieSceneGeometryFactory.makeDescriptor(sideCount: 2, sideLength: 96)
		XCTAssertTrue(d2.isCoin)
		XCTAssertFalse(d2.isToken)
		XCTAssertEqual(d2.geometry.materials.count, 3)

		let d37 = DiceSingleDieSceneGeometryFactory.makeDescriptor(sideCount: 37, sideLength: 96)
		XCTAssertFalse(d37.isCoin)
		XCTAssertTrue(d37.isToken)
		XCTAssertEqual(d37.faceValueCount, 37)
		XCTAssertEqual(d37.geometry.materials.count, 3)
	}

	func testSingleDieSceneGeometryFactoryReturnsFiniteOrientations() {
		let scenarios: [(sideCount: Int, values: [Int])] = [
			(2, [1, 2]),
			(4, [1, 4]),
			(6, [1, 6]),
			(8, [1, 8]),
			(10, [1, 10]),
			(12, [1, 12]),
			(20, [1, 20]),
			(21, [1, 21]),
		]

		for scenario in scenarios {
			for value in scenario.values {
				let orientation = DiceSingleDieSceneGeometryFactory.orientation(for: value, sideCount: scenario.sideCount)
				XCTAssertTrue(
					orientation.x.isFinite && orientation.y.isFinite && orientation.z.isFinite,
					"Expected finite orientation for d\(scenario.sideCount) value \(value)"
				)
			}
		}
	}

	func testSingleDieSceneGeometryFactoryUsesScaleRelativeCylinderThickness() {
		let coin = DiceSingleDieSceneGeometryFactory.makeDescriptor(sideCount: 2, sideLength: 1.8)
		guard let coinGeometry = coin.geometry as? SCNCylinder else {
			return XCTFail("Expected d2 to use cylinder geometry")
		}
		XCTAssertEqual(coinGeometry.height, 1.8 * 0.14, accuracy: 0.0001)
		XCTAssertLessThan(coinGeometry.height, 1.0)

		let token = DiceSingleDieSceneGeometryFactory.makeDescriptor(sideCount: 21, sideLength: 1.8)
		guard let tokenGeometry = token.geometry as? SCNCylinder else {
			return XCTFail("Expected non-polyhedral dN to use cylinder geometry")
		}
		XCTAssertEqual(tokenGeometry.height, 1.8 * 0.30, accuracy: 0.0001)
		XCTAssertLessThan(tokenGeometry.height, 1.0)
	}

	func testSingleDieMaterialPlannerReturnsExpectedCoinTokenAndPolyPlans() {
		let coinPlan = DiceSingleDieMaterialPlanner.makePlan(sideCount: 2, currentValue: 2, faceValueCount: 2)
		XCTAssertEqual(coinPlan.slots, [.side, .face(value: 1), .face(value: 2)])
		XCTAssertTrue(coinPlan.appliesCylindricalCapUVCompensation)

		let tokenPlan = DiceSingleDieMaterialPlanner.makePlan(sideCount: 21, currentValue: 17, faceValueCount: 21)
		XCTAssertEqual(tokenPlan.slots, [.side, .face(value: 17), .face(value: 17)])
		XCTAssertTrue(tokenPlan.appliesCylindricalCapUVCompensation)

		let polyPlan = DiceSingleDieMaterialPlanner.makePlan(sideCount: 20, currentValue: 8, faceValueCount: 20)
		XCTAssertEqual(polyPlan.slots.count, 20)
		XCTAssertEqual(polyPlan.slots.first, .face(value: 1))
		XCTAssertEqual(polyPlan.slots.last, .face(value: 20))
		XCTAssertFalse(polyPlan.appliesCylindricalCapUVCompensation)
	}

	func testSingleDieMaterialPlannerAppliesCylindricalCapTextureTransforms() {
		let top = SCNMaterial()
		let bottom = SCNMaterial()
		DiceSingleDieMaterialPlanner.applyCylindricalCapTextureCompensation(top: top, bottom: bottom)

		XCTAssertNotEqual(top.diffuse.contentsTransform.m11, SCNMatrix4Identity.m11)
		XCTAssertNotEqual(bottom.diffuse.contentsTransform.m11, SCNMatrix4Identity.m11)
		XCTAssertEqual(top.normal.contentsTransform.m11, top.diffuse.contentsTransform.m11, accuracy: 0.0001)
		XCTAssertEqual(bottom.normal.contentsTransform.m11, bottom.diffuse.contentsTransform.m11, accuracy: 0.0001)

		let topDeterminant = top.diffuse.contentsTransform.m11 * top.diffuse.contentsTransform.m22 - top.diffuse.contentsTransform.m12 * top.diffuse.contentsTransform.m21
		let bottomDeterminant = bottom.diffuse.contentsTransform.m11 * bottom.diffuse.contentsTransform.m22 - bottom.diffuse.contentsTransform.m12 * bottom.diffuse.contentsTransform.m21
		XCTAssertGreaterThan(topDeterminant, 0, "Top cap UV transform must preserve winding (no mirrored symbols).")
		XCTAssertGreaterThan(bottomDeterminant, 0, "Bottom cap UV transform must preserve winding (no mirrored symbols).")
	}

	func testWatchCustomizeStoryboardUsesContentSizedButtons() throws {
		let projectRoot = URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent()
			.deletingLastPathComponent()
		let storyboardURL = projectRoot
			.appendingPathComponent("Dice WatchKit App")
			.appendingPathComponent("Base.lproj")
			.appendingPathComponent("Interface.storyboard")
		let source = try String(contentsOf: storyboardURL, encoding: .utf8)

		func elementHasExplicitHeight(id: String) -> Bool {
			let patterns = [
				#"id="\#(id)"[^>]*\bheight=""#,
				#"\bheight="[^>]*id="\#(id)""#
			]
			for pattern in patterns {
				guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
				if regex.firstMatch(
					in: source,
					range: NSRange(source.startIndex..<source.endIndex, in: source)
				) != nil {
					return true
				}
			}
			return false
		}

		XCTAssertFalse(elementHasExplicitHeight(id: "R5G-Kz-oXf"))
		XCTAssertFalse(elementHasExplicitHeight(id: "naG-PB-b0v"))
		XCTAssertFalse(elementHasExplicitHeight(id: "uqH-Iz-Xnq"))
		XCTAssertFalse(elementHasExplicitHeight(id: "u7a-rw-Q3F"))
		XCTAssertFalse(source.contains("id=\"v0X-RQ-SY2\""))
		XCTAssertTrue(source.contains("selector=\"decrementSideCount\""))
		XCTAssertTrue(source.contains("selector=\"incrementSideCount\""))
		XCTAssertFalse(source.contains("selector=\"sideCountPickerChanged:\""))
		XCTAssertFalse(source.contains("selector=\"closeCustomize\""))
	}

	func testWatchSceneRenderFallbackPolicyPrefersSceneKitForHighCostGeometryWhenSharedPathIsAvailable() {
		let decision = WatchSceneRenderFallbackPolicy.resolve(
			rawSideCount: 21,
			isSceneViewReady: true,
			canBuildSharedGeometry: { _ in true }
		)
		XCTAssertEqual(decision, .sceneKit(sideCount: 21))
	}

	func testWatchSceneRenderFallbackPolicyFallsBackWhenSceneViewIsUnavailable() {
		let decision = WatchSceneRenderFallbackPolicy.resolve(
			rawSideCount: 6,
			isSceneViewReady: false,
			canBuildSharedGeometry: { _ in true }
		)
		XCTAssertEqual(decision, .staticImage(sideCount: 6, reason: .sceneViewUnavailable))
	}

	func testWatchSceneRenderFallbackPolicyFallsBackForUnsupportedSideCount() {
		let decision = WatchSceneRenderFallbackPolicy.resolve(
			rawSideCount: 101,
			isSceneViewReady: true,
			canBuildSharedGeometry: { _ in true }
		)
		XCTAssertEqual(decision, .staticImage(sideCount: 100, reason: .unsupportedSideCount))
	}

	func testWatchSceneRenderFallbackPolicyFallsBackWhenHighCostSharedPathIsUnavailable() {
		let decision = WatchSceneRenderFallbackPolicy.resolve(
			rawSideCount: 37,
			isSceneViewReady: true,
			canBuildSharedGeometry: { _ in false }
		)
		XCTAssertEqual(
			decision,
			.staticImage(sideCount: 37, reason: .sharedGeometryUnavailable(isHighCost: true))
		)
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
		XCTAssertEqual(viewModel.statusText(lastValue: third), "d6 • Result 3")
		_ = D6FaceOrientation.eulerAngles(for: first)
		_ = D6FaceOrientation.eulerAngles(for: second)
		_ = D6FaceOrientation.eulerAngles(for: third)

		viewModel.toggleMode()
		let afterToggle = viewModel.roll()
		XCTAssertEqual(afterToggle.totalRolls, 1)
		XCTAssertEqual(afterToggle.values, [4])
		XCTAssertEqual(viewModel.statusText(lastValue: 4), "d6 • Result 4")
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
		let controller = makeController()
		let commands = controller.keyCommands ?? []
		let commandInputs = Set(commands.compactMap(\.input))
		XCTAssertTrue(commandInputs.contains("r"))
		XCTAssertTrue(commandInputs.contains("h"))
		XCTAssertTrue(commandInputs.contains("f"))
	}

	func testControllerExposesFloatingShowStatsButtonWithChartIconAndText() {
		let defaults = UserDefaults.standard
		let key = "Dice.showStats"
		let originalValue = defaults.object(forKey: key)
		defer {
			if let originalValue {
				defaults.set(originalValue, forKey: key)
			} else {
				defaults.removeObject(forKey: key)
			}
		}

		defaults.set(false, forKey: key)
		let controller = makeController()
		controller.loadViewIfNeeded()
		let showStatsButton = findView(in: controller.view, accessibilityIdentifier: "showStatsButton") as? UIButton
		XCTAssertNotNil(showStatsButton)
		XCTAssertEqual(showStatsButton?.configuration?.title, NSLocalizedString("button.show-stats", comment: "Show button title"))
		XCTAssertNotNil(showStatsButton?.configuration?.image)
		XCTAssertEqual(showStatsButton?.isHidden, false)
	}

	func testControllerHidesFloatingShowStatsButtonWhenStatsAreVisible() {
		let defaults = UserDefaults.standard
		let key = "Dice.showStats"
		let originalValue = defaults.object(forKey: key)
		defer {
			if let originalValue {
				defaults.set(originalValue, forKey: key)
			} else {
				defaults.removeObject(forKey: key)
			}
		}

		defaults.set(true, forKey: key)
		let controller = makeController()
		controller.loadViewIfNeeded()
		let showStatsButton = findView(in: controller.view, accessibilityIdentifier: "showStatsButton") as? UIButton
		XCTAssertNotNil(showStatsButton)
		XCTAssertEqual(showStatsButton?.isHidden, true)
	}

	func testControllerPlacesPrimaryControlsInNavigationBar() {
		let controller = makeController()
		controller.loadViewIfNeeded()
		let notationField = findView(in: controller.navigationItem.titleView ?? UIView(), accessibilityIdentifier: "notationField")
		XCTAssertNotNil(notationField)
		XCTAssertEqual(controller.navigationItem.rightBarButtonItems?.count, 2)
		let presetsItem = controller.navigationItem.rightBarButtonItems?.first(where: { $0.accessibilityIdentifier == "presetsButton" })
		XCTAssertNotNil(presetsItem?.image)
		XCTAssertNil(presetsItem?.title)
		XCTAssertEqual(presetsItem?.accessibilityLabel, NSLocalizedString("a11y.presets.label", comment: "Presets button accessibility label"))
	}

	func testControllerNotationFieldUsesFlexibleNavigationTitleWidth() {
		let controller = makeController()
		let navigationController = UINavigationController(rootViewController: controller)
		navigationController.loadViewIfNeeded()
		controller.loadViewIfNeeded()
		navigationController.view.frame = CGRect(x: 0, y: 0, width: 932, height: 430)
		navigationController.view.setNeedsLayout()
		navigationController.view.layoutIfNeeded()

		let titleView = controller.navigationItem.titleView
		let notationField = findView(in: titleView ?? UIView(), accessibilityIdentifier: "notationField") as? UITextField
		let titleWidthConstraint = titleView?.constraints.first(where: { $0.firstAttribute == .width })
		XCTAssertNotNil(notationField)
		XCTAssertGreaterThan(titleWidthConstraint?.constant ?? 0, 320)
	}

	func testControllerNotationFieldWidthShrinksWhenNavigationBarCompacts() {
		let controller = makeController()
		let navigationController = UINavigationController(rootViewController: controller)
		navigationController.loadViewIfNeeded()
		controller.loadViewIfNeeded()

		navigationController.view.frame = CGRect(x: 0, y: 0, width: 932, height: 430)
		navigationController.view.setNeedsLayout()
		navigationController.view.layoutIfNeeded()

		let titleView = controller.navigationItem.titleView
		let titleWidthConstraint = titleView?.constraints.first(where: { $0.firstAttribute == .width })
		let wideConstant = titleWidthConstraint?.constant ?? 0
		XCTAssertGreaterThan(wideConstant, 320)

		navigationController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
		navigationController.view.setNeedsLayout()
		navigationController.view.layoutIfNeeded()

		let compactConstant = titleWidthConstraint?.constant ?? 0
		XCTAssertLessThan(compactConstant, wideConstant)
		XCTAssertLessThanOrEqual(compactConstant, 260, "Compact nav width should never keep a wide fixed title width.")
	}

	func testControllerNotationTitleWidthConstraintIsNotRequiredPriority() {
		let controller = makeController()
		controller.loadViewIfNeeded()
		let titleView = controller.navigationItem.titleView
		let titleWidthConstraint = titleView?.constraints.first(where: { $0.firstAttribute == .width })
		XCTAssertNotNil(titleWidthConstraint)
		XCTAssertLessThan(
			titleWidthConstraint?.priority.rawValue ?? UILayoutPriority.required.rawValue,
			UILayoutPriority.required.rawValue,
			"Title width should be non-required to avoid transient navigation bar width conflicts during size transitions."
		)
	}

	func testControllerAppliesDarkThemeNotationFieldPalette() {
		let defaults = UserDefaults.standard
		let key = "Dice.theme"
		let originalValue = defaults.object(forKey: key)
		defer {
			if let originalValue {
				defaults.set(originalValue, forKey: key)
			} else {
				defaults.removeObject(forKey: key)
			}
		}

		defaults.set("darkMode", forKey: key)
		let controller = makeController()
		controller.loadViewIfNeeded()
		let notationField = findView(in: controller.navigationItem.titleView ?? UIView(), accessibilityIdentifier: "notationField") as? UITextField
		XCTAssertNotNil(notationField)
		XCTAssertEqual(notationField?.borderStyle, UITextField.BorderStyle.none)
		XCTAssertEqual(notationField?.textColor, DiceTheme.darkMode.palette.primaryTextColor)
		XCTAssertEqual(notationField?.backgroundColor, DiceTheme.darkMode.palette.panelBackgroundColor)
	}

	func testControllerUsesBottomCenteredRollButtonAndMovesItAboveStatsSheet() {
		let defaults = UserDefaults.standard
		let key = "Dice.showStats"
		let originalValue = defaults.object(forKey: key)
		defer {
			if let originalValue {
				defaults.set(originalValue, forKey: key)
			} else {
				defaults.removeObject(forKey: key)
			}
		}

		func rollButtonMinY(statsVisible: Bool) -> CGFloat {
			defaults.set(statsVisible, forKey: key)
			let controller = makeController()
			controller.loadViewIfNeeded()
			let rollButton = findView(in: controller.view, accessibilityIdentifier: "rollButton") as? UIButton
			XCTAssertNotNil(rollButton)
			XCTAssertEqual(rollButton?.configuration?.title, NSLocalizedString("button.roll", comment: "Roll button title"))
			XCTAssertNotNil(rollButton?.configuration?.image)
			let bottomConstraint = controller.view.constraints.first {
				($0.firstItem as? UIButton) === rollButton && $0.firstAttribute == .bottom
			}
			XCTAssertNotNil(bottomConstraint)
			return bottomConstraint?.constant ?? 0
		}

		let hiddenBottomConstant = rollButtonMinY(statsVisible: false)
		let visibleBottomConstant = rollButtonMinY(statsVisible: true)
		XCTAssertLessThan(visibleBottomConstant, hiddenBottomConstant)
	}

	func testDieAccessibilityIdentifierParsesExpectedFormat() {
		XCTAssertEqual(DiceCubeView.dieIndex(fromAccessibilityIdentifier: "die_0"), 0)
		XCTAssertEqual(DiceCubeView.dieIndex(fromAccessibilityIdentifier: "die_12"), 12)
		XCTAssertEqual(DiceCubeView.dieAccessibilityIdentifier(for: 7), "die_7")
	}

	func testControllerUsesInspectorSheetForDieActions() {
		XCTAssertTrue(DiceViewController.debugUsesDieInspectorSheetForDieActions)
	}

	func testDieInspectorUsesPipStyleForD6() {
		XCTAssertEqual(DieInspectorSheetViewController.styleSectionKind(for: 6), .d6Pips)
	}

	func testDieInspectorUsesNumeralFontForNonD6Dice() {
		XCTAssertEqual(DieInspectorSheetViewController.styleSectionKind(for: 20), .numeralFont)
		XCTAssertEqual(DieInspectorSheetViewController.styleSectionKind(for: 4), .numeralFont)
	}

	func testControllerEmbedsDiceBoardSurfaceDirectly() {
		let controller = makeController()
		controller.loadViewIfNeeded()
		let board = findView(in: controller.view, accessibilityIdentifier: "diceBoardView")
		XCTAssertNotNil(board)
		XCTAssertTrue(board is DiceCubeView)
	}

	func testTableSurfaceShaderModifierLoadsFromBundle() {
		let source = DiceShaderModifierSourceLoader.tableSurfaceShaderModifier()
		XCTAssertNotNil(source)
		XCTAssertTrue(source?.contains("tableTextureMode") ?? false)
		XCTAssertTrue(
			source?.contains(
				"float2 feltBase = _surface.position.xy * 0.24;"
			) ?? false
		)
		XCTAssertTrue(
			source?.contains("float2 woodPos = _surface.position.xy * 0.11;") ??
				false
		)
		XCTAssertTrue(
			source?.contains(
				"float knotSpacing = 26.0;"
			) ?? false
		)
		XCTAssertTrue(source?.contains("float tableFbm2(") ?? false)
		XCTAssertTrue(source?.contains("float2 feltWarped =") ?? false)
		XCTAssertTrue(source?.contains("float macro = tableFbm2(") ?? false)
		XCTAssertTrue(source?.contains("float fibers = (fiberA + fiberB) * 0.5;") ?? false)
		XCTAssertTrue(source?.contains("float knotCore = smoothstep(0.52, 0.90, knotField);") ?? false)
	}

	func testDiceTableTextureShaderModeValuesMatchSharedPipelineContract() {
		XCTAssertEqual(DiceTableTexture.felt.shaderModeValue.intValue, 0)
		XCTAssertEqual(DiceTableTexture.wood.shaderModeValue.intValue, 1)
		XCTAssertEqual(DiceTableTexture.neutral.shaderModeValue.intValue, 2)
		XCTAssertEqual(DiceTableTexture.black.shaderModeValue.intValue, 3)
	}

	func testDiceCubeViewMapsTableTextureModesForShaderUniform() {
		XCTAssertEqual(DiceCubeView.debugTableTextureMode(for: .felt), 0)
		XCTAssertEqual(DiceCubeView.debugTableTextureMode(for: .wood), 1)
		XCTAssertEqual(DiceCubeView.debugTableTextureMode(for: .neutral), 2)
		XCTAssertEqual(DiceCubeView.debugTableTextureMode(for: .black), 3)
	}

	@MainActor
	func testDiceCubeViewBlackTextureRendersZeroRgb() {
		let snapshots = DiceCubeView.debugShadowSnapshots(tableTexture: .black)
		guard let stats = pixelStats(in: snapshots.withoutShadow, sampleRect: snapshots.sampleRect) else {
			XCTFail("Expected readable pixel stats for black table texture")
			return
		}
		XCTAssertLessThanOrEqual(stats.meanR, 0.001)
		XCTAssertLessThanOrEqual(stats.meanG, 0.001)
		XCTAssertLessThanOrEqual(stats.meanB, 0.001)
	}

	@MainActor
	func testDiceCubeViewUsesDirectionalShadowLightAndTableReceivesShadows() {
		let configuration = DiceCubeView.debugLightingConfiguration()
		XCTAssertFalse(configuration.autoenablesDefaultLighting)
		XCTAssertEqual(configuration.keyLightType, .directional)
		XCTAssertTrue(configuration.keyLightCastsShadow)
		XCTAssertEqual(configuration.keyLightShadowMode, .forward)
		XCTAssertGreaterThan(configuration.keyLightShadowRadius, 0)
		XCTAssertLessThan(configuration.fillLightIntensity, configuration.keyLightIntensity)
		XCTAssertGreaterThan(configuration.tableWidthSegmentCount, 1)
		XCTAssertGreaterThan(configuration.tableHeightSegmentCount, 1)
		XCTAssertTrue(configuration.tableLitPerPixel)
		XCTAssertNotEqual(configuration.tableLightingModel, .constant)
		XCTAssertTrue(configuration.tableReadsDepth)
		XCTAssertTrue(configuration.tableWritesDepth)
	}

	@MainActor
	func testDiceCubeViewCastsMeasurableTableShadowForAllTableTextures() {
		for texture in DiceTableTexture.allCases {
			let snapshots = DiceCubeView.debugShadowSnapshots(tableTexture: texture)
			guard let delta = shadowDeltaStats(withShadow: snapshots.withShadow, withoutShadow: snapshots.withoutShadow) else {
				XCTFail("Expected readable shadow delta stats for \(texture.rawValue)")
				return
			}
			if texture == .black {
				XCTAssertGreaterThanOrEqual(
					delta.meanDelta,
					-0.001,
					"Pure black tables cannot darken further; shadow delta should remain near zero for \(texture.rawValue)"
				)
				XCTAssertLessThanOrEqual(
					delta.darkenedPixelRatio,
					0.002,
					"Pure black tables should not report large darkened regions for \(texture.rawValue)"
				)
				continue
			}
			XCTAssertNotEqual(
				snapshots.withShadow.pngData(),
				snapshots.withoutShadow.pngData(),
				"Expected rendered output to differ when shadow casting is toggled for \(texture.rawValue)"
			)
			XCTAssertLessThan(
				delta.meanDelta,
				-0.003,
				"Expected visible shadow darkening for \(texture.rawValue)"
			)
			XCTAssertGreaterThan(
				delta.darkenedPixelRatio,
				0.006,
				"Expected a measurable darkened area for \(texture.rawValue)"
			)
		}
	}

	func testDiceCubeViewPlacesShadowCastersAtTableContactDepth() {
		let cases: [(sideCount: Int, value: Int)] = [
			(2, 1),
			(3, 2),
			(4, 4),
			(6, 5),
			(8, 7),
			(10, 6),
			(12, 9),
			(20, 17),
			(21, 11)
		]
		for entry in cases {
			let gap = DiceCubeView.debugShadowCasterGapToTable(
				sideLength: 96,
				sideCount: entry.sideCount,
				value: entry.value
			)
			XCTAssertGreaterThanOrEqual(gap, 0, "Gap should not be negative for d\(entry.sideCount)")
			XCTAssertLessThanOrEqual(gap, 0.35, "Gap should remain near-contact for d\(entry.sideCount)")
		}
	}

	@MainActor
	func testDiceCubeViewLightingDirectionRespondsToNaturalTimeAndFixedMode() {
		let tz = TimeZone(secondsFromGMT: 0)!
		let calendar = Calendar(identifier: .gregorian)
		let dateAtNoon = calendar.date(from: DateComponents(
			calendar: calendar,
			timeZone: tz,
			year: 2026,
			month: 6,
			day: 21,
			hour: 12
		))!
		let dateAtMidnight = calendar.date(from: DateComponents(
			calendar: calendar,
			timeZone: tz,
			year: 2026,
			month: 6,
			day: 21,
			hour: 0
		))!

		let naturalNoon = DiceCubeView.debugLightDirection(
			mode: .natural,
			date: dateAtNoon,
			timeZone: tz,
			isNorthernHemisphere: true
		)
		let naturalMidnight = DiceCubeView.debugLightDirection(
			mode: .natural,
			date: dateAtMidnight,
			timeZone: tz,
			isNorthernHemisphere: true
		)
		let fixed = DiceCubeView.debugLightDirection(
			mode: .fixed,
			date: dateAtNoon,
			timeZone: tz,
			isNorthernHemisphere: true
		)

		XCTAssertGreaterThan(naturalNoon.z, naturalMidnight.z)
		XCTAssertNotEqual(naturalNoon.x, naturalMidnight.x, accuracy: 0.001)
		XCTAssertEqual(
			fixed,
			DiceCubeView.debugLightDirection(
				mode: .fixed,
				date: dateAtMidnight,
				timeZone: tz,
				isNorthernHemisphere: true
			)
		)
	}

	func testDiceCubeViewKeepsTableTextureScaleStableAcrossRotation() {
		let portrait = DiceCubeView.debugTableTextureScale(for: CGSize(width: 390, height: 844))
		let landscape = DiceCubeView.debugTableTextureScale(for: CGSize(width: 844, height: 390))
		XCTAssertEqual(portrait, landscape, accuracy: 0.001)
	}

	func testDiceCubeViewUsesPointMappedNeutralTextureScale() {
		let size = CGSize(width: 390, height: 844)
		let pointScale = DiceCubeView.debugTableTexturePointScale(for: size)

		XCTAssertEqual(pointScale.width, size.width, accuracy: 0.001)
		XCTAssertEqual(pointScale.height, size.height, accuracy: 0.001)
	}

	func testDiceCubeViewMapsNeutralTexturePixelsToPoints() {
		let size = CGSize(width: 390, height: 844)
		let texturePixels = DiceCubeView.debugNeutralTableTexturePixelSize()
		let repeats = DiceCubeView.debugNeutralTableTextureRepeat(for: size)

		XCTAssertGreaterThan(texturePixels.width, 0)
		XCTAssertGreaterThan(texturePixels.height, 0)
		XCTAssertEqual(repeats.width, size.width / texturePixels.width, accuracy: 0.001)
		XCTAssertEqual(repeats.height, size.height / texturePixels.height, accuracy: 0.001)
	}

	func testDiceCubeViewOversizesTablePlaneForCoverage() {
		let size = CGSize(width: 390, height: 844)
		let planeSize = DiceCubeView.debugTablePlaneSize(for: size)

		XCTAssertGreaterThanOrEqual(planeSize.width, size.width)
		XCTAssertGreaterThanOrEqual(planeSize.height, size.height)
	}

	func testDiceCubeViewTablePlaneHasMarginAtZeroDice() {
		let size = CGSize(width: 390, height: 844)
		let planeSize = DiceCubeView.debugTablePlaneSize(for: size)
		XCTAssertGreaterThan(planeSize.width, size.width + 40)
		XCTAssertGreaterThan(planeSize.height, size.height + 40)
	}

	func testDiceCubeViewTablePlaneExpandsForOverflowingContent() {
		let base = DiceCubeView.debugRequiredTablePlaneSize(
			bounds: CGRect(x: 0, y: 0, width: 390, height: 844),
			cameraPanRangeY: 0...0,
			contentBounds: nil
		)
		let expanded = DiceCubeView.debugRequiredTablePlaneSize(
			bounds: CGRect(x: 0, y: 0, width: 390, height: 844),
			cameraPanRangeY: -420...420,
			contentBounds: CGRect(x: -180, y: -320, width: 360, height: 1680)
		)

		XCTAssertGreaterThan(expanded.height, base.height + 300)
		XCTAssertGreaterThanOrEqual(expanded.width, base.width)
	}

	func testDiceCubeViewCameraPanRangeExpandsWhenDiceOverflowViewport() {
		let range = DiceCubeView.debugCameraPanRange(
			contentMinY: -420,
			contentMaxY: 420,
			viewportHeight: 640
		)
		XCTAssertEqual(range.lowerBound, -100, accuracy: 0.001)
		XCTAssertEqual(range.upperBound, 100, accuracy: 0.001)
	}

	func testDiceCubeViewCameraPanRangeCollapsesWhenDiceFitViewport() {
		let range = DiceCubeView.debugCameraPanRange(
			contentMinY: -120,
			contentMaxY: 120,
			viewportHeight: 640
		)
		XCTAssertEqual(range.lowerBound, 0, accuracy: 0.001)
		XCTAssertEqual(range.upperBound, 0, accuracy: 0.001)
	}

	func testDiceCubeViewCameraPanIgnoresHorizontalDragAndClampsVertically() {
		let offset = DiceCubeView.debugCameraPanOffset(
			startOffsetY: 20,
			translation: CGPoint(x: 480, y: -260),
			range: -180...180
		)
		XCTAssertEqual(offset, -180, accuracy: 0.001)
	}

	private func makeController() -> DiceViewController {
		DiceViewController()
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

	func testDieAccessibilityIdentifierRejectsInvalidValues() {
		XCTAssertNil(DiceCubeView.dieIndex(fromAccessibilityIdentifier: nil))
		XCTAssertNil(DiceCubeView.dieIndex(fromAccessibilityIdentifier: "dieButton_2"))
		XCTAssertNil(DiceCubeView.dieIndex(fromAccessibilityIdentifier: "die_"))
		XCTAssertNil(DiceCubeView.dieIndex(fromAccessibilityIdentifier: "die_x"))
	}

	func testBoardAnimationLockedIndicesUsesPersistentLocksWhenNoAnimationSubsetProvided() {
		let locked = DiceViewController.boardAnimationLockedIndices(
			totalDice: 5,
			persistentLocked: [1, 4],
			animatingIndices: nil
		)
		XCTAssertEqual(locked, Set([1, 4]))
	}

	func testBoardAnimationLockedIndicesFreezesNonTargetDiceForSingleDieAnimation() {
		let locked = DiceViewController.boardAnimationLockedIndices(
			totalDice: 5,
			persistentLocked: [1],
			animatingIndices: [3]
		)
		XCTAssertEqual(locked, Set([0, 1, 2, 4]))
	}

	func testBoardLayoutNeedsRefreshWhenNoPreviousBounds() {
		let needsRefresh = DiceViewController.boardLayoutNeedsRefresh(
			previousBounds: nil,
			currentBounds: CGRect(x: 0, y: 0, width: 300, height: 500)
		)
		XCTAssertTrue(needsRefresh)
	}

	func testBoardLayoutNeedsRefreshOnlyWhenSizeChanges() {
		let previous = CGRect(x: 0, y: 0, width: 300, height: 500)
		let sameSizeDifferentOrigin = CGRect(x: 40, y: 80, width: 300, height: 500)
		let changedWidth = CGRect(x: 0, y: 0, width: 320, height: 500)

		XCTAssertFalse(
			DiceViewController.boardLayoutNeedsRefresh(
				previousBounds: previous,
				currentBounds: sameSizeDifferentOrigin
			)
		)
		XCTAssertTrue(
			DiceViewController.boardLayoutNeedsRefresh(
				previousBounds: previous,
				currentBounds: changedWidth
			)
		)
	}

	func testDiceCubeViewExposesPerDieAccessibilityElements() {
		let view = DiceCubeView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
		view.setDice(
			values: [3, 5],
			centers: [CGPoint(x: 100, y: 100), CGPoint(x: 200, y: 200)],
			sideLength: 80,
			sideCounts: [6, 20],
			lockedIndices: [1],
			animated: false
		)
		let first = view.accessibilityElementForDie(at: 0)
		let second = view.accessibilityElementForDie(at: 1)
		XCTAssertEqual(first?.accessibilityIdentifier, "die_0")
		XCTAssertEqual(second?.accessibilityIdentifier, "die_1")
		XCTAssertEqual(second?.accessibilityHint, NSLocalizedString("a11y.die.lockedHint", comment: "Locked die accessibility hint"))
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

	func testD2UsesCoinGeometryProfile() {
		let d2 = DiceCubeView.debugFallbackCylinderProfile(sideCount: 2, sideLength: 100)
		let d37 = DiceCubeView.debugFallbackCylinderProfile(sideCount: 37, sideLength: 100)
		XCTAssertEqual(d2.typeName, "SCNCylinder")
		XCTAssertEqual(d2.materialCount, 3)
		XCTAssertLessThan(d2.height, d37.height)
	}

	func testNonPolyhedralDiceUseTokenGeometryProfile() {
		let token = DiceCubeView.debugFallbackCylinderProfile(sideCount: 37, sideLength: 100)
		XCTAssertEqual(token.typeName, "SCNCylinder")
		XCTAssertEqual(token.materialCount, 3)
		XCTAssertGreaterThan(token.height, 0)
	}

	func testTokenGeometryFacesCameraByDefault() {
		let d2Orientation = DiceCubeView.debugOrientation(value: 1, sideCount: 2)
		let d37Orientation = DiceCubeView.debugOrientation(value: 11, sideCount: 37)
		XCTAssertEqual(d2Orientation.x, Float.pi * 0.5, accuracy: 0.0001)
		XCTAssertEqual(d37Orientation.x, Float.pi * 0.5, accuracy: 0.0001)
	}

	func testD2UsesOpposingFaceOrientationsForValues() {
		let value1 = DiceCubeView.debugOrientation(value: 1, sideCount: 2)
		let value2 = DiceCubeView.debugOrientation(value: 2, sideCount: 2)
		XCTAssertEqual(value1.x, -value2.x, accuracy: 0.0001)
	}

	func testCoinAnimationStartsEdgeOnAndSettlesFaceOn() {
		let start = DiceCubeView.debugCylindricalAnimationEulerAngles(sideCount: 2, targetValue: 1, progress: 0.0, motionScale: 1.0, spinDirection: 1)
		let middle = DiceCubeView.debugCylindricalAnimationEulerAngles(sideCount: 2, targetValue: 1, progress: 0.5, motionScale: 1.0, spinDirection: 1)
		let end = DiceCubeView.debugCylindricalAnimationEulerAngles(sideCount: 2, targetValue: 1, progress: 1.0, motionScale: 1.0, spinDirection: 1)
		XCTAssertEqual(start.x, 0, accuracy: 0.0001)
		XCTAssertGreaterThan(middle.x, 0)
		XCTAssertEqual(end.x, Float.pi * 0.5, accuracy: 0.0001)
	}

	func testCoinAnimationSpinDeceleratesToTargetOrientation() {
		let target = DiceCubeView.debugOrientation(value: 1, sideCount: 2)
		let start = DiceCubeView.debugCylindricalAnimationEulerAngles(sideCount: 2, targetValue: 1, progress: 0.0, motionScale: 1.0, spinDirection: 1)
		let mid = DiceCubeView.debugCylindricalAnimationEulerAngles(sideCount: 2, targetValue: 1, progress: 0.5, motionScale: 1.0, spinDirection: 1)
		let nearEnd = DiceCubeView.debugCylindricalAnimationEulerAngles(sideCount: 2, targetValue: 1, progress: 0.9, motionScale: 1.0, spinDirection: 1)
		let end = DiceCubeView.debugCylindricalAnimationEulerAngles(sideCount: 2, targetValue: 1, progress: 1.0, motionScale: 1.0, spinDirection: 1)
		XCTAssertGreaterThan(abs(start.z - target.z), abs(mid.z - target.z))
		XCTAssertGreaterThan(abs(mid.z - target.z), abs(nearEnd.z - target.z))
		XCTAssertEqual(end.z, target.z, accuracy: 0.0001)
	}

	func testTokenAnimationUsesSameEdgeOnToFaceOnProfile() {
		let start = DiceCubeView.debugCylindricalAnimationEulerAngles(sideCount: 37, targetValue: 11, progress: 0.0, motionScale: 1.0, spinDirection: 1)
		let end = DiceCubeView.debugCylindricalAnimationEulerAngles(sideCount: 37, targetValue: 11, progress: 1.0, motionScale: 1.0, spinDirection: 1)
		XCTAssertEqual(start.x, 0, accuracy: 0.0001)
		XCTAssertEqual(end.x, Float.pi * 0.5, accuracy: 0.0001)
	}

	func testCylindricalDiceUsePinnedBoardPositionDuringRoll() {
		XCTAssertTrue(DiceCubeView.debugUsesPinnedRollPosition(sideCount: 2))
		XCTAssertTrue(DiceCubeView.debugUsesPinnedRollPosition(sideCount: 37))
		XCTAssertFalse(DiceCubeView.debugUsesPinnedRollPosition(sideCount: 6))
	}

	func testCylindricalPinnedDepthStartsAtRadiusAndSettlesToCurrentTargetDepth() {
		let sideLength: CGFloat = 100
		let expectedStartGap = sideLength * 0.48 + 0.15

		let d2Start = DiceCubeView.debugPinnedRollDepthGaps(
			sideLength: sideLength,
			sideCount: 2,
			value: 1,
			progress: 0
		)
		XCTAssertEqual(d2Start.start, expectedStartGap, accuracy: 0.25)
		XCTAssertEqual(d2Start.current, d2Start.start, accuracy: 0.0001)

		let d2Mid = DiceCubeView.debugPinnedRollDepthGaps(
			sideLength: sideLength,
			sideCount: 2,
			value: 1,
			progress: 0.5
		)
		XCTAssertLessThan(d2Mid.current, d2Mid.start)
		XCTAssertGreaterThan(d2Mid.current, d2Mid.end)

		let d2End = DiceCubeView.debugPinnedRollDepthGaps(
			sideLength: sideLength,
			sideCount: 2,
			value: 1,
			progress: 1
		)
		XCTAssertEqual(d2End.current, d2End.end, accuracy: 0.0001)

		let d21Start = DiceCubeView.debugPinnedRollDepthGaps(
			sideLength: sideLength,
			sideCount: 21,
			value: 7,
			progress: 0
		)
		XCTAssertEqual(d21Start.start, expectedStartGap, accuracy: 0.25)
		XCTAssertGreaterThan(d21Start.start, d21Start.end + 25)
	}

	func testCoinCapsUseFaceTexturesForVisibleSymbols() {
		let summary = DiceCubeView.debugCoinCapTextureSummary(fillColor: UIColor(red: 0.86, green: 0.62, blue: 0.22, alpha: 1))
		XCTAssertFalse(summary.sideUsesImageTexture)
		XCTAssertTrue(summary.topUsesImageTexture)
		XCTAssertTrue(summary.bottomUsesImageTexture)
		XCTAssertFalse(summary.topAndBottomShareSameReference)
	}

	func testTokenCapsUseFaceTexturesForVisibleSymbols() {
		let summary = DiceCubeView.debugTokenCapTextureSummary(
			sideCount: 37,
			value: 11,
			fillColor: UIColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 1)
		)
		XCTAssertFalse(summary.sideUsesImageTexture)
		XCTAssertTrue(summary.topUsesImageTexture)
		XCTAssertTrue(summary.bottomUsesImageTexture)
	}

	func testCoinCapsApplyQuarterTurnTextureOrientationCompensation() {
		let transform = DiceCubeView.debugCoinCapTransformSummary(fillColor: UIColor(red: 0.86, green: 0.62, blue: 0.22, alpha: 1))
		XCTAssertEqual(transform.topM11, 0, accuracy: 0.0001)
		XCTAssertEqual(abs(transform.topM12), 1.04, accuracy: 0.0001)
		XCTAssertEqual(transform.bottomM11, 0, accuracy: 0.0001)
		XCTAssertEqual(abs(transform.bottomM12), 1.04, accuracy: 0.0001)
		let topDeterminant = transform.topM11 * transform.topM22 - transform.topM12 * transform.topM21
		let bottomDeterminant = transform.bottomM11 * transform.bottomM22 - transform.bottomM12 * transform.bottomM21
		XCTAssertLessThan(topDeterminant, 0)
		XCTAssertLessThan(bottomDeterminant, 0)
		XCTAssertGreaterThanOrEqual(transform.topM41, -0.03)
		XCTAssertGreaterThanOrEqual(transform.topM42, -0.03)
		XCTAssertGreaterThanOrEqual(transform.bottomM41, -0.03)
		XCTAssertGreaterThanOrEqual(transform.bottomM42, -0.03)
		XCTAssertLessThanOrEqual(transform.topM41, 1.03)
		XCTAssertLessThanOrEqual(transform.topM42, 1.03)
		XCTAssertLessThanOrEqual(transform.bottomM41, 1.03)
		XCTAssertLessThanOrEqual(transform.bottomM42, 1.03)
	}

	func testTokenCapsApplyQuarterTurnTextureOrientationCompensation() {
		let transform = DiceCubeView.debugTokenCapTransformSummary(
			sideCount: 5,
			value: 3,
			fillColor: UIColor(red: 0.82, green: 0.82, blue: 0.88, alpha: 1)
		)
		XCTAssertEqual(transform.topM11, 0, accuracy: 0.0001)
		XCTAssertEqual(abs(transform.topM12), 1.04, accuracy: 0.0001)
		XCTAssertEqual(transform.bottomM11, 0, accuracy: 0.0001)
		XCTAssertEqual(abs(transform.bottomM12), 1.04, accuracy: 0.0001)
		let topDeterminant = transform.topM11 * transform.topM22 - transform.topM12 * transform.topM21
		let bottomDeterminant = transform.bottomM11 * transform.bottomM22 - transform.bottomM12 * transform.bottomM21
		XCTAssertLessThan(topDeterminant, 0)
		XCTAssertLessThan(bottomDeterminant, 0)
		XCTAssertGreaterThanOrEqual(transform.topM41, -0.03)
		XCTAssertGreaterThanOrEqual(transform.topM42, -0.03)
		XCTAssertGreaterThanOrEqual(transform.bottomM41, -0.03)
		XCTAssertGreaterThanOrEqual(transform.bottomM42, -0.03)
		XCTAssertLessThanOrEqual(transform.topM41, 1.03)
		XCTAssertLessThanOrEqual(transform.topM42, 1.03)
		XCTAssertLessThanOrEqual(transform.bottomM41, 1.03)
		XCTAssertLessThanOrEqual(transform.bottomM42, 1.03)
	}

	func testCylindricalFaceTextureLayoutUsesReadableCaptionRatioAndNoRectBorder() {
		let coinLayout = DiceCubeView.debugFaceValueTextureLayoutSummary(sideCount: 2)
		XCTAssertEqual(coinLayout.captionSize / coinLayout.numeralSize, 0.5, accuracy: 0.01)
		XCTAssertFalse(coinLayout.drawsBorder)

		let tokenLayout = DiceCubeView.debugFaceValueTextureLayoutSummary(sideCount: 5)
		XCTAssertEqual(tokenLayout.captionSize / tokenLayout.numeralSize, 0.5, accuracy: 0.01)
		XCTAssertFalse(tokenLayout.drawsBorder)

		let polyhedralLayout = DiceCubeView.debugFaceValueTextureLayoutSummary(sideCount: 20)
		XCTAssertTrue(polyhedralLayout.drawsBorder)
		XCTAssertLessThan(polyhedralLayout.captionSize / polyhedralLayout.numeralSize, 0.3)
	}

	func testDiceCubeViewUsesUniqueGeometryInstancesPerDie() {
		XCTAssertTrue(DiceCubeView.debugUsesUniqueGeometryPerDie(sideCount: 6))
	}

	func testDiceCubeViewSkipsMaterialRebuildWhenOnlyValuesChange() {
		let counts = DiceCubeView.debugMaterialRefreshCountsForConsecutiveSetDice(
			valuesFirst: [1, 2, 3],
			valuesSecond: [4, 5, 6],
			sideCounts: [6, 6, 6],
			colorOverrides: [.amber, .sapphire, .crimson],
			fontOverrides: [nil, nil, nil]
		)
		XCTAssertGreaterThan(counts.firstPass, 0)
		XCTAssertEqual(counts.secondPass, 0)
	}

	func testDiceCubeViewRebuildsMaterialsWhenSideLengthChanges() {
		let counts = DiceCubeView.debugMaterialRefreshCountsForSideLengthChange(
			values: [2, 7],
			sideCounts: [6, 20],
			colorOverrides: [.amber, .sapphire],
			fontOverrides: [nil, nil],
			sideLengthFirst: 88,
			sideLengthSecond: 116
		)
		XCTAssertGreaterThan(counts.firstPass, 0)
		XCTAssertGreaterThan(counts.secondPass, 0)
	}

	func testDiceCubeViewFontChangeReusesCachedMeshes() {
		let counts = DiceCubeView.debugMeshBuildCountsForGlobalFontChange(
			values: [2, 7, 11],
			sideCounts: [6, 8, 20],
			colorOverrides: [.amber, .sapphire, .crimson],
			fontInitial: .classic,
			fontChanged: .serif
		)
		XCTAssertGreaterThan(counts.firstPass, 0)
		XCTAssertEqual(counts.secondPass, 0)
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

	private struct ShadowDeltaStats {
		let meanDelta: Double
		let darkenedPixelRatio: Double
	}

	private func shadowDeltaStats(withShadow: UIImage, withoutShadow: UIImage) -> ShadowDeltaStats? {
		guard
			let withShadowImage = withShadow.cgImage,
			let withoutShadowImage = withoutShadow.cgImage,
			withShadowImage.width == withoutShadowImage.width,
			withShadowImage.height == withoutShadowImage.height
		else {
			return nil
		}

		let width = withShadowImage.width
		let height = withShadowImage.height
		guard width > 0, height > 0 else { return nil }

		let bytesPerPixel = 4
		let bytesPerRow = bytesPerPixel * width
		let pixelCount = width * height
		var withPixels = Array(repeating: UInt8(0), count: bytesPerRow * height)
		var withoutPixels = Array(repeating: UInt8(0), count: bytesPerRow * height)

		guard
			let withContext = CGContext(
				data: &withPixels,
				width: width,
				height: height,
				bitsPerComponent: 8,
				bytesPerRow: bytesPerRow,
				space: CGColorSpaceCreateDeviceRGB(),
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
			),
			let withoutContext = CGContext(
				data: &withoutPixels,
				width: width,
				height: height,
				bitsPerComponent: 8,
				bytesPerRow: bytesPerRow,
				space: CGColorSpaceCreateDeviceRGB(),
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
			)
		else {
			return nil
		}
		withContext.draw(withShadowImage, in: CGRect(x: 0, y: 0, width: width, height: height))
		withoutContext.draw(withoutShadowImage, in: CGRect(x: 0, y: 0, width: width, height: height))

		var totalDelta = 0.0
		var darkenedCount = 0
		let darkenedThreshold = 0.015
		for pixelIndex in 0..<pixelCount {
			let offset = pixelIndex * bytesPerPixel
			let withR = Double(withPixels[offset]) / 255.0
			let withG = Double(withPixels[offset + 1]) / 255.0
			let withB = Double(withPixels[offset + 2]) / 255.0
			let withoutR = Double(withoutPixels[offset]) / 255.0
			let withoutG = Double(withoutPixels[offset + 1]) / 255.0
			let withoutB = Double(withoutPixels[offset + 2]) / 255.0
			let withL = (0.2126 * withR) + (0.7152 * withG) + (0.0722 * withB)
			let withoutL = (0.2126 * withoutR) + (0.7152 * withoutG) + (0.0722 * withoutB)
			let delta = withL - withoutL
			totalDelta += delta
			if delta <= -darkenedThreshold {
				darkenedCount += 1
			}
		}

		let count = Double(pixelCount)
		guard count > 0 else { return nil }
		return ShadowDeltaStats(
			meanDelta: totalDelta / count,
			darkenedPixelRatio: Double(darkenedCount) / count
		)
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
