//
//  DiceViewModel.swift
//  Dice
//
//  Created by Codex on 16.02.26.
//

import Foundation

final class DiceViewModel {
	private let notationParser: DiceNotationParser
	private let preferencesStore: DicePreferencesStore
	private let historyStore: DiceRollHistoryStore
	private let telemetry: DiceTelemetry
	private let rollSession: DiceRollSession
	private let historyExporter: RollHistoryExporter

	private(set) var appState: DiceAppState
	private var rollHistory: DiceRollHistory

	init(
		notationParser: DiceNotationParser = DiceNotationParser(),
		preferencesStore: DicePreferencesStore = DicePreferencesStore(),
		historyStore: DiceRollHistoryStore = DiceRollHistoryStore(),
		telemetry: DiceTelemetry = DiceTelemetry(),
		rollSession: DiceRollSession = DiceRollSession(),
		historyExporter: RollHistoryExporter = RollHistoryExporter(),
		appState: DiceAppState = DiceAppState(),
		rollHistory: DiceRollHistory = DiceRollHistory()
	) {
		self.notationParser = notationParser
		self.preferencesStore = preferencesStore
		self.historyStore = historyStore
		self.telemetry = telemetry
		self.rollSession = rollSession
		self.historyExporter = historyExporter
		self.appState = appState
		self.rollHistory = rollHistory
	}

	var configuration: RollConfiguration {
		appState.configuration
	}

	var diceValues: [Int] {
		appState.diceValues
	}

	var diceSideCounts: [Int] {
		appState.diceSideCounts
	}

	var historyEntries: [RollHistoryEntry] {
		rollHistory.sessionEntries
	}

	var recentPresets: [String] {
		preferencesStore.load().recentPresets
	}

	var customPresets: [DiceSavedPreset] {
		preferencesStore.load().customPresets
	}

	var animationsEnabled: Bool {
		appState.animationsEnabled
	}

	var animationIntensity: DiceAnimationIntensity {
		appState.animationIntensity
	}

	var theme: DiceTheme {
		appState.theme
	}

	var tableTexture: DiceTableTexture {
		appState.tableTexture
	}

	var dieFinish: DiceDieFinish {
		appState.dieFinish
	}

	var edgeOutlinesEnabled: Bool {
		appState.edgeOutlinesEnabled
	}

	var dieColorPreferences: DiceDieColorPreferences {
		appState.dieColorPreferences
	}

	var d6PipStyle: DiceD6PipStyle {
		appState.d6PipStyle
	}

	var faceNumeralFont: DiceFaceNumeralFont {
		appState.faceNumeralFont
	}

	var largeFaceLabelsEnabled: Bool {
		appState.largeFaceLabelsEnabled
	}

	var lockedDieIndices: Set<Int> {
		appState.lockedDieIndices
	}

	var motionBlurEnabled: Bool {
		appState.motionBlurEnabled
	}

	var boardLayoutPreset: DiceBoardLayoutPreset {
		appState.boardLayoutPreset
	}

	var soundPack: DiceSoundPack {
		appState.soundPack
	}

	var soundEffectsEnabled: Bool {
		appState.soundEffectsEnabled
	}

	var hapticsEnabled: Bool {
		appState.hapticsEnabled
	}

	var dieColorOverridesByIndex: [Int: DiceDieColorPreset] {
		appState.dieColorOverrides
	}

	var dieFaceNumeralFontOverridesByIndex: [Int: DiceFaceNumeralFont] {
		appState.dieFaceNumeralFontOverrides
	}

	func restore() {
		let preferences = preferencesStore.load()
		if let parsed = notationParser.parse(preferences.lastNotation) {
			appState.configuration = parsed
			appState.diceSideCounts = parsed.sideCountsPerDie
			appState.diceValues = Array(repeating: 1, count: parsed.diceCount)
			applyNotationColorOverrides(from: parsed)
		} else {
			appState.diceSideCounts = appState.configuration.sideCountsPerDie
			appState.diceValues = Array(repeating: 1, count: appState.configuration.diceCount)
			appState.dieColorOverrides = [:]
		}
		appState.animationsEnabled = preferences.animationsEnabled
		appState.animationIntensity = preferences.animationIntensity
		appState.theme = preferences.theme
		appState.tableTexture = preferences.tableTexture
		appState.dieFinish = preferences.dieFinish
		appState.edgeOutlinesEnabled = preferences.edgeOutlinesEnabled
		appState.dieColorPreferences = preferences.dieColorPreferences
		appState.d6PipStyle = preferences.d6PipStyle
		appState.faceNumeralFont = preferences.faceNumeralFont
		appState.largeFaceLabelsEnabled = preferences.largeFaceLabelsEnabled
		appState.motionBlurEnabled = preferences.motionBlurEnabled
		appState.boardLayoutPreset = preferences.boardLayoutPreset
		appState.soundPack = preferences.soundPack
		appState.soundEffectsEnabled = preferences.soundEffectsEnabled
		appState.hapticsEnabled = preferences.hapticsEnabled
		let persisted = historyStore.loadPersistedEntries()
		rollHistory = DiceRollHistory(persistedRecentEntries: persisted)
	}

	func rollFromInput(_ text: String) -> Result<RollOutcome, DiceInputError> {
		switch notationParser.parseResult(text) {
		case let .success(parsed):
			if appState.configuration.sideCountsPerDie != parsed.sideCountsPerDie {
				appState.lockedDieIndices.removeAll()
				appState.dieFaceNumeralFontOverrides.removeAll()
			}
			appState.configuration = parsed
			applyNotationColorOverrides(from: parsed)
			preferencesStore.addRecentPreset(parsed.notation)
			persistPreferences()
			return .success(performRoll())
		case let .failure(error):
			telemetry.logInvalidInput(text, reason: error.userMessage)
			return .failure(error)
		}
	}

	func notationHint(for text: String) -> String? {
		let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return nil }
		switch notationParser.parseResult(text) {
		case .success:
			return nil
		case let .failure(error):
			return error.userMessage
		}
	}

	func rollCurrent() -> RollOutcome {
		performRoll()
	}

	func repeatLastRoll() -> RollOutcome {
		let configuration = appState.lastRolledConfiguration ?? appState.configuration
		appState.configuration = configuration
		persistPreferences()
		return performRoll(configuration: configuration)
	}

	func shakeToRoll() -> RollOutcome {
		performRoll()
	}

	func selectPreset(diceCount: Int, intuitive: Bool) -> RollOutcome {
		appState.configuration = RollConfiguration(diceCount: diceCount, sideCount: 6, intuitive: intuitive)
		appState.lockedDieIndices.removeAll()
		preferencesStore.addRecentPreset(appState.configuration.notation)
		persistPreferences()
		return performRoll()
	}

	func saveCustomPresets(_ presets: [DiceSavedPreset]) {
		var preferences = preferencesStore.load()
		preferences.customPresets = presets
		preferencesStore.save(preferences)
	}

	func createCustomPreset(title: String, notation: String) -> Result<Void, DiceInputError> {
		switch notationParser.parseResult(notation) {
		case .failure(let error):
			return .failure(error)
		case .success:
			var presets = customPresets
			presets.append(DiceSavedPreset(title: title, notation: notation))
			saveCustomPresets(presets)
			return .success(())
		}
	}

	func rerollDie(at index: Int) -> RollOutcome? {
		guard diceValues.indices.contains(index) else { return nil }
		guard appState.diceSideCounts.indices.contains(index) else { return nil }
		guard !appState.lockedDieIndices.contains(index) else { return nil }
		let singleRoll = RollConfiguration(diceCount: 1, sideCount: appState.diceSideCounts[index], intuitive: appState.configuration.intuitive)
		let outcome = rollSession.roll(singleRoll)
		guard let newValue = outcome.values.first else { return nil }
		appState.diceValues[index] = newValue
		if let newSideCount = outcome.sideCounts.first {
			appState.diceSideCounts[index] = newSideCount
		}
		appState.stats = DiceStats(outcome: outcome)
		appendHistory(for: singleRoll, outcome: outcome)
		telemetry.logRoll(configuration: singleRoll, sum: outcome.sum, diceCount: singleRoll.diceCount)
		return outcome
	}

	func resetStats() {
		rollSession.reset()
		appState.stats = .empty
		telemetry.logStatsReset()
	}

	func clearHistory() {
		clearRecentHistory()
		clearPersistedHistory()
	}

	func clearRecentHistory() {
		rollHistory.clearSession()
	}

	func clearPersistedHistory() {
		rollHistory.clearPersistedRecent()
		historyStore.savePersistedEntries([])
	}

	func exportHistory(format: RollHistoryExportFormat) -> String {
		historyExporter.export(rollHistory.sessionEntries, format: format)
	}

	func historyHistograms(maxEntries: Int = 60) -> [RollHistogram] {
		RollHistoryAnalytics.histograms(entries: rollHistory.sessionEntries, maxEntries: maxEntries)
	}

	func historyHistogramSummary(maxEntries: Int = 60) -> String? {
		let histograms = historyHistograms(maxEntries: maxEntries)
		return RollHistoryAnalytics.histogramSummaryText(histograms)
	}

	func historyIndicators(maxEntries: Int = 60) -> RollHistoryIndicators {
		RollHistoryAnalytics.indicators(entries: rollHistory.sessionEntries, maxEntries: maxEntries)
	}

	func historySessionSummary(entries: [RollHistoryEntry]? = nil) -> RollSessionSummary {
		RollHistoryAnalytics.sessionSummary(entries: entries ?? rollHistory.sessionEntries)
	}

	func setAnimationsEnabled(_ enabled: Bool) {
		appState.animationsEnabled = enabled
		if enabled && appState.animationIntensity == .off {
			appState.animationIntensity = .full
		}
		if !enabled {
			appState.animationIntensity = .off
		}
		persistPreferences()
	}

	func setAnimationIntensity(_ intensity: DiceAnimationIntensity) {
		appState.animationIntensity = intensity
		appState.animationsEnabled = intensity != .off
		persistPreferences()
	}

	func setTheme(_ theme: DiceTheme) {
		appState.theme = theme
		persistPreferences()
	}

	func setTableTexture(_ tableTexture: DiceTableTexture) {
		appState.tableTexture = tableTexture
		persistPreferences()
	}

	func setDieFinish(_ dieFinish: DiceDieFinish) {
		appState.dieFinish = dieFinish
		persistPreferences()
	}

	func setEdgeOutlinesEnabled(_ enabled: Bool) {
		appState.edgeOutlinesEnabled = enabled
		persistPreferences()
	}

	func dieColorPreset(for sideCount: Int) -> DiceDieColorPreset {
		appState.dieColorPreferences.preset(for: sideCount)
	}

	func dieColorPreset(forDieAt index: Int) -> DiceDieColorPreset? {
		appState.dieColorOverrides[index]
	}

	func setDieColorPreset(_ preset: DiceDieColorPreset, forDieAt index: Int) {
		guard appState.diceValues.indices.contains(index) else { return }
		appState.dieColorOverrides[index] = preset
	}

	func applyPerDieColorSelection(_ preset: DiceDieColorPreset, at index: Int) {
		guard appState.configuration.sideCountsPerDie.indices.contains(index) else { return }
		let updatedPools = recoloredPools(
			from: appState.configuration.pools,
			dieIndex: index,
			colorTag: preset.notationName
		)
		appState.configuration = RollConfiguration(pools: updatedPools)
		applyNotationColorOverrides(from: appState.configuration)
		persistPreferences()
	}

	func setDieColorPreset(_ preset: DiceDieColorPreset, for sideCount: Int) {
		appState.dieColorPreferences = appState.dieColorPreferences.updated(sideCount: sideCount, preset: preset)
		persistPreferences()
	}

	func setD6PipStyle(_ style: DiceD6PipStyle) {
		appState.d6PipStyle = style
		persistPreferences()
	}

	func setFaceNumeralFont(_ font: DiceFaceNumeralFont) {
		appState.faceNumeralFont = font
		persistPreferences()
	}

	func faceNumeralFont(forDieAt index: Int) -> DiceFaceNumeralFont? {
		appState.dieFaceNumeralFontOverrides[index]
	}

	func setFaceNumeralFont(_ font: DiceFaceNumeralFont, forDieAt index: Int) {
		guard appState.diceValues.indices.contains(index) else { return }
		appState.dieFaceNumeralFontOverrides[index] = font
	}

	func setLargeFaceLabelsEnabled(_ enabled: Bool) {
		appState.largeFaceLabelsEnabled = enabled
		persistPreferences()
	}

	func setMotionBlurEnabled(_ enabled: Bool) {
		appState.motionBlurEnabled = enabled
		persistPreferences()
	}

	func setBoardLayoutPreset(_ preset: DiceBoardLayoutPreset) {
		appState.boardLayoutPreset = preset
		persistPreferences()
	}

	func setSoundPack(_ pack: DiceSoundPack) {
		appState.soundPack = pack
		persistPreferences()
	}

	func setSoundEffectsEnabled(_ enabled: Bool) {
		appState.soundEffectsEnabled = enabled
		persistPreferences()
	}

	func setHapticsEnabled(_ enabled: Bool) {
		appState.hapticsEnabled = enabled
		persistPreferences()
	}

	func isDieLocked(at index: Int) -> Bool {
		appState.lockedDieIndices.contains(index)
	}

	func toggleDieLock(at index: Int) {
		guard appState.diceValues.indices.contains(index) else { return }
		if appState.lockedDieIndices.contains(index) {
			appState.lockedDieIndices.remove(index)
		} else {
			appState.lockedDieIndices.insert(index)
		}
	}

	func resetVisualPreferences() {
		appState.theme = .system
		appState.tableTexture = .neutral
		appState.dieFinish = .matte
		appState.edgeOutlinesEnabled = false
		appState.dieColorPreferences = .default
		appState.d6PipStyle = .round
		appState.faceNumeralFont = .classic
		appState.largeFaceLabelsEnabled = false
		appState.motionBlurEnabled = false
		persistPreferences()
	}

	func formattedTotalsText(outcome: RollOutcome, boardSupportedSides: Set<Int>) -> String {
		var lines: [String] = []
		lines.append(String(
			format: NSLocalizedString("stats.mode", comment: "Current mode and notation"),
			locale: .current,
			localizedModeLabel(for: appState.configuration)
		))
		lines.append(String(
			format: NSLocalizedString("stats.notation", comment: "Current notation line"),
			locale: .current,
			appState.configuration.notation
		))

		if appState.configuration.diceCount > 1 {
			let localCounts = formattedCounts(outcome.localTotals)
			if !localCounts.isEmpty {
				lines.append(String(
					format: NSLocalizedString("stats.rollCounts", comment: "Per-roll counts line"),
					locale: .current,
					localCounts
				))
			}
			lines.append(String(
				format: NSLocalizedString("stats.rollSum", comment: "Per-roll sum line"),
				locale: .current,
				outcome.sum
			))
		}

		let sessionCounts = formattedCounts(outcome.sessionTotals)
		if !sessionCounts.isEmpty {
			lines.append(String(
				format: NSLocalizedString("stats.sessionCounts", comment: "Session counts line"),
				locale: .current,
				sessionCounts
			))
		}
		lines.append(String(
			format: NSLocalizedString("stats.sessionTotalDice", comment: "Session total dice line"),
			locale: .current,
			outcome.totalRolls
		))
		let unsupportedSides = Set(appState.diceSideCounts.filter { !boardSupportedSides.contains($0) })
		if unsupportedSides.count == 1, let sideCount = unsupportedSides.first {
			lines.append(String(
				format: NSLocalizedString("stats.boardUnavailable", comment: "3D board unsupported sides message"),
				locale: .current,
				sideCount
			))
		} else if unsupportedSides.count > 1 {
			lines.append(NSLocalizedString("stats.boardUnavailableMixed", comment: "3D board unsupported mixed sides message"))
		}

		return "  " + lines.joined(separator: "\n  ")
	}

	private func performRoll(configuration: RollConfiguration? = nil) -> RollOutcome {
		let activeConfiguration = configuration ?? appState.configuration
		let previousValues = appState.diceValues
		let previousSideCounts = appState.diceSideCounts
		let outcome = lockAwareRoll(
			configuration: activeConfiguration,
			previousValues: previousValues,
			previousSideCounts: previousSideCounts
		)
		appState.lastRolledConfiguration = activeConfiguration
		appState.applyRollOutcome(outcome)
		appendHistory(for: activeConfiguration, outcome: outcome)
		telemetry.logRoll(configuration: activeConfiguration, sum: outcome.sum, diceCount: activeConfiguration.diceCount)
		return outcome
	}

	private func localizedModeLabel(for configuration: RollConfiguration) -> String {
		let key: String
		if configuration.hasIntuitivePools && configuration.hasTrueRandomPools {
			key = "stats.mode.mixed"
		} else {
			key = configuration.hasIntuitivePools ? "stats.mode.intuitive" : "stats.mode.trueRandom"
		}
		return NSLocalizedString(key, comment: "Localized mode label in stats output")
	}

	private func lockAwareRoll(configuration: RollConfiguration, previousValues: [Int], previousSideCounts: [Int]) -> RollOutcome {
		guard !appState.lockedDieIndices.isEmpty else {
			return rollSession.roll(configuration)
		}
		guard previousValues.count == configuration.diceCount,
			  previousSideCounts == configuration.sideCountsPerDie else {
			appState.lockedDieIndices.removeAll()
			return rollSession.roll(configuration)
		}

		let allIndices = Set(configuration.sideCountsPerDie.indices)
		let unlockedIndices = allIndices.subtracting(appState.lockedDieIndices).sorted()
		if unlockedIndices.isEmpty {
			let localTotals = localTotalsFromValues(previousValues, sideCounts: previousSideCounts)
			return RollOutcome(
				values: previousValues,
				sideCounts: previousSideCounts,
				localTotals: localTotals,
				sessionTotals: appState.stats.sessionTotals,
				totalRolls: appState.stats.totalRolls,
				sum: previousValues.reduce(0, +)
			)
		}

		let sideCounts = configuration.sideCountsPerDie
		let intuitiveFlags = configuration.perDieIntuitiveFlags
		var unlockedPools: [DicePool] = []
		var currentCount = 0
		var currentSides = 0
		var currentIntuitive = false
		for index in unlockedIndices {
			let sides = sideCounts[index]
			let intuitive = intuitiveFlags[index]
			if currentCount == 0 {
				currentCount = 1
				currentSides = sides
				currentIntuitive = intuitive
				continue
			}
			if currentSides == sides && currentIntuitive == intuitive {
				currentCount += 1
			} else {
				unlockedPools.append(DicePool(diceCount: currentCount, sideCount: currentSides, intuitive: currentIntuitive))
				currentCount = 1
				currentSides = sides
				currentIntuitive = intuitive
			}
		}
		if currentCount > 0 {
			unlockedPools.append(DicePool(diceCount: currentCount, sideCount: currentSides, intuitive: currentIntuitive))
		}

		let unlockedOutcome = rollSession.roll(RollConfiguration(pools: unlockedPools))
		var mergedValues = previousValues
		var unlockedCursor = 0
		for index in unlockedIndices where unlockedCursor < unlockedOutcome.values.count {
			mergedValues[index] = unlockedOutcome.values[unlockedCursor]
			unlockedCursor += 1
		}
		let localTotals = localTotalsFromValues(mergedValues, sideCounts: sideCounts)
		return RollOutcome(
			values: mergedValues,
			sideCounts: sideCounts,
			localTotals: localTotals,
			sessionTotals: unlockedOutcome.sessionTotals,
			totalRolls: unlockedOutcome.totalRolls,
			sum: mergedValues.reduce(0, +)
		)
	}

	private func localTotalsFromValues(_ values: [Int], sideCounts: [Int]) -> [Int] {
		let maxSides = sideCounts.max() ?? 0
		var localTotals = Array(repeating: 0, count: maxSides)
		for value in values where value > 0 && value <= maxSides {
			localTotals[value - 1] += 1
		}
		return localTotals
	}

	private func persistPreferences() {
		let preferences = DiceUserPreferences(
			lastNotation: appState.configuration.notation,
			recentPresets: preferencesStore.load().recentPresets,
			animationsEnabled: appState.animationsEnabled,
			animationIntensity: appState.animationIntensity,
			theme: appState.theme,
			tableTexture: appState.tableTexture,
			dieFinish: appState.dieFinish,
			edgeOutlinesEnabled: appState.edgeOutlinesEnabled,
			dieColorPreferences: appState.dieColorPreferences,
			d6PipStyle: appState.d6PipStyle,
			faceNumeralFont: appState.faceNumeralFont,
			largeFaceLabelsEnabled: appState.largeFaceLabelsEnabled,
			customPresets: preferencesStore.load().customPresets,
			motionBlurEnabled: appState.motionBlurEnabled,
			boardLayoutPreset: appState.boardLayoutPreset,
			soundPack: appState.soundPack,
			soundEffectsEnabled: appState.soundEffectsEnabled,
			hapticsEnabled: appState.hapticsEnabled
		)
		preferencesStore.save(preferences)
	}

	private func applyNotationColorOverrides(from configuration: RollConfiguration) {
		let colorTags = configuration.perDieColorTags
		var overrides: [Int: DiceDieColorPreset] = [:]
		for (index, tag) in colorTags.enumerated() {
			if let tag, let preset = DiceDieColorPreset.fromNotation(tag) {
				overrides[index] = preset
			}
		}
		appState.dieColorOverrides = overrides
	}

	private func appendHistory(for configuration: RollConfiguration, outcome: RollOutcome) {
		let entry = RollHistoryEntry(
			timestamp: Date(),
			notation: configuration.notation,
			values: outcome.values,
			sum: outcome.sum,
			intuitive: configuration.intuitive
		)
		rollHistory.append(entry)
		historyStore.savePersistedEntries(rollHistory.persistedRecentEntries)
	}

	private func formattedCounts(_ totals: [Int]) -> String {
		if totals.isEmpty { return "" }
		if totals.count > 40 {
			let nonZero = totals.enumerated().filter { $0.element > 0 }
			let top = nonZero.sorted { $0.element > $1.element }.prefix(10)
			return top.map { "\($0.offset + 1)s:\($0.element)" }.joined(separator: " ")
		}
		return totals.enumerated().map { "\($0.offset + 1)s:\($0.element)" }.joined(separator: " ")
	}

	private func recoloredPools(from pools: [DicePool], dieIndex: Int, colorTag: String) -> [DicePool] {
		var rebuilt: [DicePool] = []
		rebuilt.reserveCapacity(pools.count + 2)

		var remainingIndex = dieIndex
		var didApply = false
		for pool in pools {
			if didApply {
				rebuilt.append(pool)
				continue
			}
			if remainingIndex >= pool.diceCount {
				rebuilt.append(pool)
				remainingIndex -= pool.diceCount
				continue
			}

			let leftCount = remainingIndex
			let rightCount = pool.diceCount - remainingIndex - 1
			if leftCount > 0 {
				rebuilt.append(DicePool(
					diceCount: leftCount,
					sideCount: pool.sideCount,
					intuitive: pool.intuitive,
					colorTag: pool.colorTag
				))
			}
			rebuilt.append(DicePool(
				diceCount: 1,
				sideCount: pool.sideCount,
				intuitive: pool.intuitive,
				colorTag: colorTag
			))
			if rightCount > 0 {
				rebuilt.append(DicePool(
					diceCount: rightCount,
					sideCount: pool.sideCount,
					intuitive: pool.intuitive,
					colorTag: pool.colorTag
				))
			}
			didApply = true
		}

		return mergedAdjacentPools(rebuilt)
	}

	private func mergedAdjacentPools(_ pools: [DicePool]) -> [DicePool] {
		guard var current = pools.first else { return [] }
		var merged: [DicePool] = []
		for pool in pools.dropFirst() {
			let canMerge = current.sideCount == pool.sideCount &&
				current.intuitive == pool.intuitive &&
				current.colorTag == pool.colorTag
			if canMerge {
				current = DicePool(
					diceCount: current.diceCount + pool.diceCount,
					sideCount: current.sideCount,
					intuitive: current.intuitive,
					colorTag: current.colorTag
				)
			} else {
				merged.append(current)
				current = pool
			}
		}
		merged.append(current)
		return merged
	}
}
