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

	var lockedDieIndices: Set<Int> {
		appState.lockedDieIndices
	}

	var boardCameraPreset: DiceBoardCameraPreset {
		appState.boardCameraPreset
	}

	func restore() {
		let preferences = preferencesStore.load()
		if let parsed = notationParser.parse(preferences.lastNotation) {
			appState.configuration = parsed
		}
		appState.animationsEnabled = preferences.animationsEnabled
		appState.theme = preferences.theme
		appState.tableTexture = preferences.tableTexture
		appState.dieFinish = preferences.dieFinish
		appState.edgeOutlinesEnabled = preferences.edgeOutlinesEnabled
		appState.dieColorPreferences = preferences.dieColorPreferences
		appState.d6PipStyle = preferences.d6PipStyle
		appState.faceNumeralFont = preferences.faceNumeralFont
		appState.boardCameraPreset = preferences.boardCameraPreset
		let persisted = historyStore.loadPersistedEntries()
		rollHistory = DiceRollHistory(persistedRecentEntries: persisted)
	}

	func rollFromInput(_ text: String) -> Result<RollOutcome, DiceInputError> {
		switch notationParser.parseResult(text) {
		case let .success(parsed):
			if appState.configuration.sideCountsPerDie != parsed.sideCountsPerDie {
				appState.lockedDieIndices.removeAll()
			}
			appState.configuration = parsed
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
		rollHistory.clearSession()
		rollHistory.clearPersistedRecent()
		historyStore.savePersistedEntries([])
	}

	func exportHistory(format: RollHistoryExportFormat) -> String {
		historyExporter.export(rollHistory.sessionEntries, format: format)
	}

	func setAnimationsEnabled(_ enabled: Bool) {
		appState.animationsEnabled = enabled
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

	func setBoardCameraPreset(_ preset: DiceBoardCameraPreset) {
		appState.boardCameraPreset = preset
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
		appState.theme = .classic
		appState.tableTexture = .neutral
		appState.dieFinish = .matte
		appState.edgeOutlinesEnabled = false
		appState.dieColorPreferences = .default
		appState.d6PipStyle = .round
		appState.faceNumeralFont = .classic
		appState.boardCameraPreset = .slightTilt
		persistPreferences()
	}

	func formattedTotalsText(outcome: RollOutcome, boardSupportedSides: Set<Int>) -> String {
		var lines: [String] = []
		lines.append(String(
			format: NSLocalizedString("stats.mode", comment: "Current mode and notation"),
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
		let rawOutcome = rollSession.roll(activeConfiguration)
		let outcome = applyLocks(to: rawOutcome, previousValues: previousValues, previousSideCounts: previousSideCounts)
		appState.lastRolledConfiguration = activeConfiguration
		appState.applyRollOutcome(outcome)
		appendHistory(for: activeConfiguration, outcome: outcome)
		telemetry.logRoll(configuration: activeConfiguration, sum: outcome.sum, diceCount: activeConfiguration.diceCount)
		return outcome
	}

	private func applyLocks(to outcome: RollOutcome, previousValues: [Int], previousSideCounts: [Int]) -> RollOutcome {
		guard !appState.lockedDieIndices.isEmpty else { return outcome }
		guard previousValues.count == outcome.values.count, previousSideCounts.count == outcome.sideCounts.count else {
			appState.lockedDieIndices.removeAll()
			return outcome
		}

		var values = outcome.values
		var validLocks: Set<Int> = []
		for index in appState.lockedDieIndices where index < values.count {
			guard previousSideCounts[index] == outcome.sideCounts[index] else { continue }
			values[index] = previousValues[index]
			validLocks.insert(index)
		}
		appState.lockedDieIndices = validLocks

		let maxSides = outcome.sideCounts.max() ?? 0
		var localTotals = Array(repeating: 0, count: maxSides)
		for value in values where value > 0 && value <= maxSides {
			localTotals[value - 1] += 1
		}

		return RollOutcome(
			values: values,
			sideCounts: outcome.sideCounts,
			localTotals: localTotals,
			sessionTotals: outcome.sessionTotals,
			totalRolls: outcome.totalRolls,
			sum: values.reduce(0, +)
		)
	}

	private func persistPreferences() {
		let preferences = DiceUserPreferences(
			lastNotation: appState.configuration.notation,
			recentPresets: preferencesStore.load().recentPresets,
			animationsEnabled: appState.animationsEnabled,
			theme: appState.theme,
			tableTexture: appState.tableTexture,
			dieFinish: appState.dieFinish,
			edgeOutlinesEnabled: appState.edgeOutlinesEnabled,
			dieColorPreferences: appState.dieColorPreferences,
			d6PipStyle: appState.d6PipStyle,
			faceNumeralFont: appState.faceNumeralFont,
			customPresets: preferencesStore.load().customPresets,
			boardCameraPreset: appState.boardCameraPreset
		)
		preferencesStore.save(preferences)
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
}
