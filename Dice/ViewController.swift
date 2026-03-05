//
//  ViewController.swift
//  Dice
//
//  Created by Ben Wheatley on 2018/09/27.
//  Copyright © 2018 Ben Wheatley. All rights reserved.
//

import UIKit

class DiceViewController: UIViewController, UITextFieldDelegate {
	private let viewModel = DiceViewModel()
	private let soundEngine = DiceSoundEngine()
	private let hapticsEngine = DiceHapticsEngine()
	private var hasPerformedInitialRoll = false

	private let notationField = UITextField()
	private let rollButton = UIButton(type: .system)
	private let showStatsButton = UIButton(type: .system)
	private var presetsBarButtonItem: UIBarButtonItem?
	private var menuBarButtonItem: UIBarButtonItem?
	private var rollButtonBottomConstraint: NSLayoutConstraint?
	private let diceBoardView = DiceCubeView()
	private var currentPalette = DiceTheme.system.palette
	private var currentTexture: DiceTableTexture = .neutral
	private var currentDieFinish: DiceDieFinish = .matte
	private let statsVisibilityKey = "Dice.showStats"
	private var statsVisible = true
	private var rollDistributionSheetController: RollDistributionSheetViewController?
	private var currentTotalsGraphCounts: [Int] = []
	private var currentTotalsAccessibilityValue: String?
	private var pendingStatsSheetPresentation = false
	private let statsSheetHeight: CGFloat = 200
    private let dieInfoSheetHeight: CGFloat = 475
	private let floatingControlBottomMargin: CGFloat = 16
	private let rollButtonSpacingAboveStatsSheet: CGFloat = 12
	private var routeObserver: NSObjectProtocol?
	private var selectedDieIndex: Int?
	private weak var dieInspectorSheetController: DieInspectorSheetViewController?
	private var previousBoardLayoutBounds: CGRect?

	init() {
		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		viewModel.restore()
		syncSoundSettings()

		configureControls()
		configureDiceBoard()
		applyTheme()
		configurePointerInteractionsIfNeeded()
		updateNotationField()
		restoreStatsVisibility()
		updateStatsVisibility()
		configureAccessibilityRotors()
		updateControlMenu()
		renderRestoredState()
		observeSceneRoutes()
		refreshSystemSurfaces()
	}

	deinit {
		if let routeObserver {
			NotificationCenter.default.removeObserver(routeObserver)
		}
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		updateStatsVisibility()
		guard !hasPerformedInitialRoll else { return }
		hasPerformedInitialRoll = true
		DispatchQueue.main.async { [weak self] in
			self?.performRoll()
		}
	}

	override var keyCommands: [UIKeyCommand]? {
		[
			UIKeyCommand(title: NSLocalizedString("shortcut.roll", comment: "Roll keyboard shortcut title"), action: #selector(rollFromInput), input: "r", modifierFlags: .command),
			UIKeyCommand(title: NSLocalizedString("shortcut.repeat", comment: "Repeat roll keyboard shortcut title"), action: #selector(repeatLastRoll), input: "r", modifierFlags: [.command, .shift]),
			UIKeyCommand(title: NSLocalizedString("shortcut.reset", comment: "Reset stats keyboard shortcut title"), action: #selector(resetStats), input: "\u{8}", modifierFlags: .command),
			UIKeyCommand(title: NSLocalizedString("shortcut.focusNotation", comment: "Focus notation keyboard shortcut title"), action: #selector(focusNotationField), input: "f", modifierFlags: .command),
			UIKeyCommand(title: NSLocalizedString("shortcut.history", comment: "History keyboard shortcut title"), action: #selector(showHistory), input: "h", modifierFlags: .command),
		]
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		let currentBounds = diceBoardView.bounds
		if Self.boardLayoutNeedsRefresh(previousBounds: previousBoardLayoutBounds, currentBounds: currentBounds) {
			updateDiceBoard(animated: false)
			previousBoardLayoutBounds = currentBounds
		}
		if pendingStatsSheetPresentation, statsVisible, presentedViewController == nil {
			presentRollDistributionSheetIfNeeded()
		}
	}

	override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
		if event?.subtype == .motionShake {
			let outcome = viewModel.shakeToRoll()
			updateNotationField()
			updateTotalsText(outcome: outcome)
			updateDiceBoard(animated: shouldAnimateBoard)
			playRollSound()
			refreshSystemSurfaces()
		}
	}

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		rollFromInput()
		return true
	}

	private func configureControls() {
		notationField.translatesAutoresizingMaskIntoConstraints = false
		notationField.placeholder = NSLocalizedString("notation.placeholder", comment: "Dice notation input placeholder")
		notationField.autocapitalizationType = .none
		notationField.autocorrectionType = .no
		notationField.clearButtonMode = .whileEditing
		notationField.borderStyle = .roundedRect
		notationField.delegate = self
		notationField.accessibilityLabel = NSLocalizedString("a11y.notation.label", comment: "Notation field accessibility label")
		notationField.accessibilityHint = NSLocalizedString("a11y.notation.hint", comment: "Notation field accessibility hint")
		notationField.accessibilityIdentifier = "notationField"
		notationField.addTarget(self, action: #selector(notationEditingChanged), for: .editingChanged)
		configureNotationInputAccessory()
		notationField.widthAnchor.constraint(equalToConstant: 220).isActive = true
		navigationItem.titleView = notationField
		navigationItem.largeTitleDisplayMode = .never

		let presetsItem = UIBarButtonItem(
			image: UIImage(systemName: "bookmark"),
			style: .plain,
			target: self,
			action: #selector(showPresetPicker)
		)
		presetsItem.accessibilityLabel = NSLocalizedString("a11y.presets.label", comment: "Presets button accessibility label")
		presetsItem.accessibilityIdentifier = "presetsButton"

		let menuItem = UIBarButtonItem(
			image: UIImage(systemName: "line.3.horizontal"),
			style: .plain,
			target: self,
			action: #selector(showControlSheet)
		)
		menuItem.accessibilityLabel = NSLocalizedString("a11y.menu.label", comment: "Main menu accessibility label")
		menuItem.accessibilityIdentifier = "menuButton"

		presetsBarButtonItem = presetsItem
		menuBarButtonItem = menuItem
		navigationItem.rightBarButtonItems = [menuItem, presetsItem]

		rollButton.translatesAutoresizingMaskIntoConstraints = false
		var rollButtonConfig = UIButton.Configuration.filled()
		rollButtonConfig.title = NSLocalizedString("button.roll", comment: "Roll button title")
		rollButtonConfig.image = UIImage(systemName: "die.face.5")
		rollButtonConfig.imagePlacement = .leading
		rollButtonConfig.imagePadding = 6
		rollButtonConfig.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
		rollButtonConfig.background.cornerRadius = 18
		rollButtonConfig.background.strokeWidth = 1
		rollButton.configuration = rollButtonConfig
		rollButton.addTarget(self, action: #selector(rollFromInput), for: .touchUpInside)
		rollButton.accessibilityLabel = NSLocalizedString("a11y.roll.label", comment: "Roll button accessibility label")
		rollButton.accessibilityIdentifier = "rollButton"
		rollButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
		rollButton.titleLabel?.adjustsFontForContentSizeCategory = true
		rollButton.semanticContentAttribute = .forceLeftToRight

		showStatsButton.translatesAutoresizingMaskIntoConstraints = false
		var showStatsButtonConfig = UIButton.Configuration.filled()
		showStatsButtonConfig.title = NSLocalizedString("button.show-stats", comment: "Show button title")
		showStatsButtonConfig.image = UIImage(systemName: "chart.bar.xaxis")
		showStatsButtonConfig.imagePlacement = .leading
		showStatsButtonConfig.imagePadding = 6
		showStatsButtonConfig.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
		showStatsButtonConfig.background.cornerRadius = 18
		showStatsButtonConfig.background.strokeWidth = 1
		showStatsButton.configuration = showStatsButtonConfig
		showStatsButton.addTarget(self, action: #selector(showRollDistributionSheet), for: .touchUpInside)
		showStatsButton.accessibilityLabel = NSLocalizedString("a11y.stats.show", comment: "Show stats button accessibility label")
		showStatsButton.accessibilityIdentifier = "showStatsButton"
		showStatsButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
		showStatsButton.titleLabel?.adjustsFontForContentSizeCategory = true
		showStatsButton.semanticContentAttribute = .forceLeftToRight
		view.addSubview(rollButton)
		view.addSubview(showStatsButton)
		let rollBottomConstraint = rollButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -floatingControlBottomMargin)
		rollButtonBottomConstraint = rollBottomConstraint
		NSLayoutConstraint.activate([
			rollButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
			rollBottomConstraint,
			showStatsButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -floatingControlBottomMargin),
			showStatsButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -floatingControlBottomMargin),
		])
		updateShowStatsButtonVisibility()
	}

	private func observeSceneRoutes() {
		routeObserver = NotificationCenter.default.addObserver(
			forName: .diceRouteRequested,
			object: nil,
			queue: .main
		) { [weak self] notification in
			guard let self else { return }
			if let sourceScene = notification.object as? UIWindowScene,
			   let currentScene = self.view.window?.windowScene,
			   sourceScene !== currentScene {
				return
			}
			guard let route = notification.userInfo?[DiceRouteNotificationKey.route] as? DiceAppRoute else { return }
			self.handle(route: route)
		}
	}

	private func handle(route: DiceAppRoute) {
		switch route {
		case .roll:
			rollFromInput()
		case .repeatLastRoll:
			repeatLastRoll()
		case .history:
			showHistory()
		case .presets:
			showPresetPicker()
		}
	}

	private func configureDiceBoard() {
		diceBoardView.translatesAutoresizingMaskIntoConstraints = false
		diceBoardView.backgroundColor = .clear
		diceBoardView.accessibilityIdentifier = "diceBoardView"
		diceBoardView.onRollSettled = { [weak self] in
			self?.playSettleTickSound()
		}
		diceBoardView.onDieTapped = { [weak self] index, _ in
			self?.presentDieInspector(for: index)
		}
		diceBoardView.setTableTexture(viewModel.tableTexture)
		diceBoardView.setLargeFaceLabelsEnabled(viewModel.largeFaceLabelsEnabled)
		view.addSubview(diceBoardView)
		view.bringSubviewToFront(rollButton)
		view.bringSubviewToFront(showStatsButton)
		NSLayoutConstraint.activate([
			diceBoardView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
			diceBoardView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
			diceBoardView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			diceBoardView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
		])
	}

	private func updateNotationField() {
		notationField.text = viewModel.configuration.notation
	}

	@objc private func rollFromInput() {
		guard let text = notationField.text else { return }
		switch viewModel.rollFromInput(text) {
		case let .success(outcome):
			notationField.resignFirstResponder()
			clearValidationFeedback()
			updateNotationField()
			updateTotalsText(outcome: outcome)
			updateDiceBoard(animated: shouldAnimateBoard)
			playRollSound()
			refreshSystemSurfaces()
		case let .failure(error):
			showValidationError(message: error.userMessage)
		}
	}

	@objc private func repeatLastRoll() {
		let outcome = viewModel.repeatLastRoll()
		updateNotationField()
		clearValidationFeedback()
		updateTotalsText(outcome: outcome)
		updateDiceBoard(animated: shouldAnimateBoard)
		playRollSound()
		refreshSystemSurfaces()
	}

	private func presentDieInspector(for index: Int) {
		guard viewModel.diceValues.indices.contains(index), viewModel.diceSideCounts.indices.contains(index) else { return }
		selectedDieIndex = index
		diceBoardView.setSelectedDieIndex(index)
		let state = dieInspectorState(for: index)

		if let inspector = dieInspectorSheetController, inspector.presentingViewController != nil {
			bindDieInspectorCallbacks(inspector, dieIndex: index)
			inspector.updateState(state)
			return
		}

		let inspector = DieInspectorSheetViewController(state: state)
		bindDieInspectorCallbacks(inspector, dieIndex: index)
		inspector.onDismiss = { [weak self, weak inspector] in
			guard let self else { return }
			if self.dieInspectorSheetController === inspector {
				self.dieInspectorSheetController = nil
			}
			self.selectedDieIndex = nil
			self.diceBoardView.setSelectedDieIndex(nil)
		}

		let navigationController = UINavigationController(rootViewController: inspector)
		switch viewModel.theme {
		case .lightMode:
			navigationController.overrideUserInterfaceStyle = .light
		case .darkMode:
			navigationController.overrideUserInterfaceStyle = .dark
		case .system:
			navigationController.overrideUserInterfaceStyle = .unspecified
		}
		navigationController.modalPresentationStyle = .pageSheet
        // Deliberate product decision: keep a compact fixed-height stats sheet.
        // This is intentionally constrained to avoid covering the board UI.
        let customDetent = UISheetPresentationController.Detent.custom(
            identifier: .init("fixedHeight")
        ) { _ in
            return self.dieInfoSheetHeight
        }
		if let presentationController = navigationController.sheetPresentationController {
			presentationController.detents = [customDetent]
			presentationController.prefersGrabberVisible = true
			presentationController.preferredCornerRadius = 20
		}
		present(navigationController, animated: true)
		dieInspectorSheetController = inspector
	}

	private func bindDieInspectorCallbacks(_ inspector: DieInspectorSheetViewController, dieIndex: Int) {
		inspector.onReroll = { [weak self] in
			guard let self else { return }
			_ = self.rerollDie(at: dieIndex)
		}
		inspector.onToggleLock = { [weak self] in
			guard let self else { return }
			self.toggleDieLock(at: dieIndex)
		}
		inspector.onSetColor = { [weak self] preset in
			guard let self else { return }
			self.selectDieColorPreset(preset, index: dieIndex)
		}
		inspector.onSetD6PipStyle = { [weak self] style in
			guard let self else { return }
			self.selectD6PipStyle(style)
		}
		inspector.onSetFaceNumeralFont = { [weak self] font in
			guard let self else { return }
			self.selectFaceNumeralFont(font, dieIndex: dieIndex)
		}
	}

	private func dieInspectorState(for index: Int) -> DieInspectorSheetViewController.State {
		let sideCount = viewModel.diceSideCounts[index]
		let selectedColor = viewModel.dieColorPreset(forDieAt: index) ?? viewModel.dieColorPreset(for: sideCount)
		let selectedFont = viewModel.faceNumeralFont(forDieAt: index) ?? viewModel.faceNumeralFont
		return DieInspectorSheetViewController.State(
			dieIndex: index,
			sideCount: sideCount,
			isLocked: viewModel.isDieLocked(at: index),
			selectedColor: selectedColor,
			d6PipStyle: viewModel.d6PipStyle,
			selectedFont: selectedFont
		)
	}

	private func refreshDieInspectorIfVisible() {
		guard let inspector = dieInspectorSheetController, inspector.presentingViewController != nil else { return }
		guard let index = selectedDieIndex else { return }
		guard viewModel.diceValues.indices.contains(index), viewModel.diceSideCounts.indices.contains(index) else { return }
		bindDieInspectorCallbacks(inspector, dieIndex: index)
		inspector.updateState(dieInspectorState(for: index))
	}

#if DEBUG
	static var debugUsesDieInspectorSheetForDieActions: Bool {
		true
	}
#endif

	private func performRoll() {
		let outcome = viewModel.rollCurrent()
		updateNotationField()
		updateTotalsText(outcome: outcome)
		updateDiceBoard(animated: shouldAnimateBoard)
		playRollSound()
		refreshSystemSurfaces()
	}

	private func renderRestoredState() {
		updateNotationField()
		clearValidationFeedback()
		updateDiceBoard(animated: false)
	}

	@discardableResult
	private func rerollDie(at index: Int) -> RollOutcome? {
		guard let outcome = viewModel.rerollDie(at: index) else { return nil }
		updateTotalsText(outcome: outcome)
		updateDiceBoard(animated: shouldAnimateBoard, animatingIndices: [index])
		playRollSound()
		refreshSystemSurfaces()
		return outcome
	}

	private func toggleDieLock(at index: Int) {
		viewModel.toggleDieLock(at: index)
		updateDiceBoard(animated: false)
		refreshDieInspectorIfVisible()
	}

	private func updateDiceBoard(animated: Bool, animatingIndices: Set<Int>? = nil) {
		let sideCounts = viewModel.diceSideCounts
		guard !sideCounts.isEmpty else {
			diceBoardView.isHidden = true
			diceBoardView.setDice(values: [], centers: [], sideLength: 0, sideCounts: [], animated: false)
			selectedDieIndex = nil
			diceBoardView.setSelectedDieIndex(nil)
			return
		}

		diceBoardView.isHidden = false
		diceBoardView.setDieFinish(viewModel.dieFinish)
		diceBoardView.setEdgeOutlinesEnabled(viewModel.edgeOutlinesEnabled)
		diceBoardView.setDieColorPreferences(viewModel.dieColorPreferences)
		diceBoardView.setD6PipStyle(viewModel.d6PipStyle)
		diceBoardView.setFaceNumeralFont(viewModel.faceNumeralFont)
		diceBoardView.setLargeFaceLabelsEnabled(viewModel.largeFaceLabelsEnabled)
		diceBoardView.setAnimationIntensity(viewModel.animationIntensity)
		diceBoardView.setMotionBlurEnabled(viewModel.motionBlurEnabled)

		let mixed = Set(sideCounts).count > 1
		let itemCount = min(viewModel.diceValues.count, sideCounts.count)
		let layout = Self.boardRenderLayout(
			itemCount: itemCount,
			bounds: diceBoardView.bounds,
			layoutPreset: viewModel.boardLayoutPreset,
			mixed: mixed
		)
		let centers = layout.centers
		let sideLength = layout.sideLength
		let values = Array(viewModel.diceValues.prefix(itemCount))
		let boardSideCounts = Array(sideCounts.prefix(itemCount))

		let colorOverrides = (0..<values.count).map { viewModel.dieColorOverridesByIndex[$0] }
		let fontOverrides = (0..<values.count).map { viewModel.dieFaceNumeralFontOverridesByIndex[$0] }
		let boardLockedIndices = Self.boardAnimationLockedIndices(
			totalDice: values.count,
			persistentLocked: viewModel.lockedDieIndices,
			animatingIndices: animatingIndices
		)
		diceBoardView.setDice(
			values: values,
			centers: centers,
			sideLength: sideLength,
			sideCounts: boardSideCounts,
			dieColorPresets: colorOverrides,
			faceNumeralFonts: fontOverrides,
			lockedIndices: boardLockedIndices,
			animated: animated
		)
		if let selectedDieIndex, selectedDieIndex >= values.count {
			self.selectedDieIndex = nil
		}
		diceBoardView.setSelectedDieIndex(selectedDieIndex)
	}

	static func boardAnimationLockedIndices(totalDice: Int, persistentLocked: Set<Int>, animatingIndices: Set<Int>?) -> Set<Int> {
		guard let animatingIndices else { return persistentLocked }
		let validAnimating = Set(animatingIndices.filter { $0 >= 0 && $0 < totalDice })
		var locked = persistentLocked
		for index in 0..<totalDice where !validAnimating.contains(index) {
			locked.insert(index)
		}
		return locked
	}

	static func boardLayoutNeedsRefresh(previousBounds: CGRect?, currentBounds: CGRect) -> Bool {
		guard let previousBounds else { return true }
		let widthDelta = abs(previousBounds.width - currentBounds.width)
		let heightDelta = abs(previousBounds.height - currentBounds.height)
		return widthDelta > 0.5 || heightDelta > 0.5
	}

	static func boardRenderLayout(
		itemCount: Int,
		bounds: CGRect,
		layoutPreset: DiceBoardLayoutPreset,
		mixed: Bool
	) -> (centers: [CGPoint], sideLength: CGFloat) {
		guard itemCount > 0, bounds.width > 1, bounds.height > 1 else { return ([], 0) }
		let spacingFactor: CGFloat
		switch layoutPreset {
		case .compact:
			spacingFactor = mixed ? 0.16 : 0.13
		case .spacious:
			spacingFactor = mixed ? 0.26 : 0.22
		}

		var bestColumns = 1
		var bestRows = itemCount
		var bestSideLength: CGFloat = 0
		for columns in 1...itemCount {
			let rows = Int(ceil(Double(itemCount) / Double(columns)))
			let sideByWidth = bounds.width / (CGFloat(columns) + CGFloat(columns + 1) * spacingFactor)
			let sideByHeight = bounds.height / (CGFloat(rows) + CGFloat(rows + 1) * spacingFactor)
			let candidate = min(sideByWidth, sideByHeight)
			if candidate > bestSideLength {
				bestSideLength = candidate
				bestColumns = columns
				bestRows = rows
			}
		}

		let sideLength = max(44, min(bestSideLength, min(bounds.width, bounds.height) * 0.34))
		let gap = sideLength * spacingFactor
		let rowCapacity = min(bestColumns, itemCount)
		let totalGridWidth = CGFloat(rowCapacity) * sideLength + CGFloat(max(0, rowCapacity - 1)) * gap
		let totalGridHeight = CGFloat(bestRows) * sideLength + CGFloat(max(0, bestRows - 1)) * gap
		let startX = bounds.midX - totalGridWidth / 2 + sideLength / 2
		let startY = bounds.midY - totalGridHeight / 2 + sideLength / 2

		var centers: [CGPoint] = []
		centers.reserveCapacity(itemCount)
		for index in 0..<itemCount {
			let row = index / bestColumns
			let column = index % bestColumns
			let x = startX + CGFloat(column) * (sideLength + gap)
			let y = startY + CGFloat(row) * (sideLength + gap)
			centers.append(CGPoint(x: x, y: y))
		}
		return (centers, sideLength)
	}

	@objc private func notationEditingChanged() {
		guard let text = notationField.text else {
			clearValidationFeedback()
			return
		}
		if let hint = viewModel.notationHint(for: text) {
			showValidationError(message: hint)
		} else {
			clearValidationFeedback()
		}
	}

	@objc private func focusNotationField() {
		notationField.becomeFirstResponder()
	}

	@objc private func toggleAnimations() {
		viewModel.setAnimationsEnabled(!viewModel.animationsEnabled)
		diceBoardView.setAnimationIntensity(viewModel.animationIntensity)
		updateControlMenu()
	}

	private func syncSoundSettings() {
		soundEngine.configure(pack: viewModel.soundPack, enabled: viewModel.soundEffectsEnabled)
	}

	private func playRollSound() {
		soundEngine.playRollImpact()
		if viewModel.hapticsEnabled {
			hapticsEngine.playRollImpact()
		}
	}

	private func playSettleTickSound() {
		soundEngine.playSettleTick()
		if viewModel.hapticsEnabled {
			hapticsEngine.playRollSettle()
		}
	}

	private func configureAccessibilityRotors() {
		let rerollRotor = UIAccessibilityCustomRotor(
			name: NSLocalizedString("a11y.rotor.rerollDie", comment: "VoiceOver rotor title for rerolling selected die")
		) { [weak self] predicate in
			guard let self else { return nil }
			guard let index = selectedDieIndex(from: predicate), viewModel.diceValues.indices.contains(index) else { return nil }
			if let outcome = rerollDie(at: index), let value = outcome.values.first {
				let message = String(
					format: NSLocalizedString("a11y.announcement.dieRerolled", comment: "Announcement for rerolled die value"),
					locale: .current,
					index + 1,
					value
				)
				UIAccessibility.post(notification: .announcement, argument: message)
			} else if viewModel.isDieLocked(at: index) {
				UIAccessibility.post(
					notification: .announcement,
					argument: NSLocalizedString("a11y.announcement.dieLocked", comment: "Announcement when attempting to reroll locked die")
				)
			}
			guard let dieElement = dieAccessibilityElement(at: index) else { return nil }
			return UIAccessibilityCustomRotorItemResult(targetElement: dieElement, targetRange: nil)
		}

		let readSidesRotor = UIAccessibilityCustomRotor(
			name: NSLocalizedString("a11y.rotor.readDieSides", comment: "VoiceOver rotor title for reading die side counts")
		) { [weak self] predicate in
			guard let self else { return nil }
			guard let index = selectedDieIndex(from: predicate), viewModel.diceSideCounts.indices.contains(index) else { return nil }
			let message = String(
				format: NSLocalizedString("a11y.announcement.dieSides", comment: "Announcement for die side count"),
				locale: .current,
				index + 1,
				viewModel.diceSideCounts[index]
			)
			UIAccessibility.post(notification: .announcement, argument: message)
			guard let dieElement = dieAccessibilityElement(at: index) else { return nil }
			return UIAccessibilityCustomRotorItemResult(targetElement: dieElement, targetRange: nil)
		}

		view.accessibilityCustomRotors = [rerollRotor, readSidesRotor]
	}

	private func selectedDieIndex(from predicate: UIAccessibilityCustomRotorSearchPredicate) -> Int? {
		if let identifiable = predicate.currentItem.targetElement as? UIAccessibilityIdentification,
		   let currentIdentifier = identifiable.accessibilityIdentifier,
		   let index = DiceCubeView.dieIndex(fromAccessibilityIdentifier: currentIdentifier) {
			return index
		}
		return viewModel.diceValues.isEmpty ? nil : 0
	}

	private func dieAccessibilityElement(at index: Int) -> UIAccessibilityElement? {
		diceBoardView.accessibilityElementForDie(at: index)
	}

	private func selectAnimationIntensity(_ intensity: DiceAnimationIntensity) {
		viewModel.setAnimationIntensity(intensity)
		diceBoardView.setAnimationIntensity(intensity)
		updateControlMenu()
	}

	@objc private func showHistory() {
		let indicators = viewModel.historyIndicators()
		let historyViewController = RollHistoryViewController(
			entries: viewModel.historyEntries,
			histogramSummary: viewModel.historyHistogramSummary(),
			indicatorSummary: historyIndicatorSummaryText(indicators),
			indicatorTooltip: historyIndicatorTooltipText(indicators)
		)
		historyViewController.onExportText = { [weak self] in
			guard let self else { return }
			self.presentExportSheet(content: self.viewModel.exportHistory(format: .text), filename: "dice-history.txt")
		}
		historyViewController.onExportCSV = { [weak self] in
			guard let self else { return }
			self.presentExportSheet(content: self.viewModel.exportHistory(format: .csv), filename: "dice-history.csv")
		}
		historyViewController.onClearRecentOnly = { [weak self, weak historyViewController] in
			guard let self else { return }
			self.viewModel.clearRecentHistory()
			historyViewController?.updateEntries([], histogramSummary: nil, indicatorSummary: nil, indicatorTooltip: nil)
			self.refreshSystemSurfaces()
		}
		historyViewController.onClearPersistedAll = { [weak self, weak historyViewController] in
			guard let self else { return }
			self.viewModel.clearPersistedHistory()
			historyViewController?.updateEntries([], histogramSummary: nil, indicatorSummary: nil, indicatorTooltip: nil)
			self.refreshSystemSurfaces()
		}
		historyViewController.onShareSummary = { [weak self] entries in
			self?.shareHistorySummaryCard(entries: entries)
		}
		let navigationController = UINavigationController(rootViewController: historyViewController)
		switch viewModel.theme {
		case .lightMode:
			navigationController.overrideUserInterfaceStyle = .light
		case .darkMode:
			navigationController.overrideUserInterfaceStyle = .dark
		case .system:
			navigationController.overrideUserInterfaceStyle = .unspecified
		}
		navigationController.modalPresentationStyle = .formSheet
		if let popover = navigationController.popoverPresentationController {
			popover.barButtonItem = menuBarButtonItem
		}
		present(navigationController, animated: true)
	}

	private func historyIndicatorSummaryText(_ indicators: RollHistoryIndicators) -> String? {
		guard indicators.hasHighlights else { return nil }
		let z = abs(indicators.outlierZScore ?? 0)
		let notation = indicators.outlierNotation ?? "-"
		return String(
			format: NSLocalizedString("history.indicators.summary", comment: "History indicators summary line"),
			indicators.highStreak,
			indicators.lowStreak,
			notation,
			z
		)
	}

	private func historyIndicatorTooltipText(_ indicators: RollHistoryIndicators) -> String? {
		guard indicators.hasHighlights else { return nil }
		return String(
			format: NSLocalizedString("history.indicators.tooltip", comment: "History indicators explanatory tooltip text"),
			indicators.highStreak,
			indicators.lowStreak
		)
	}

	private func presentExportSheet(content: String, filename: String) {
		let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
		do {
			try content.write(to: temporaryURL, atomically: true, encoding: .utf8)
			let activity = UIActivityViewController(activityItems: [temporaryURL], applicationActivities: nil)
			if let popover = activity.popoverPresentationController {
				popover.barButtonItem = menuBarButtonItem
			}
			present(activity, animated: true)
		} catch {
			let alert = UIAlertController(
				title: NSLocalizedString("alert.exportFailed.title", comment: "Export failed alert title"),
				message: NSLocalizedString("alert.exportFailed.message", comment: "Export failed alert message"),
				preferredStyle: .alert
			)
			alert.addAction(UIAlertAction(title: NSLocalizedString("button.ok", comment: "Generic confirmation button"), style: .default))
			present(alert, animated: true)
		}
	}

	private func refreshSystemSurfaces() {
		DiceQuickActionManager.shared.refresh()
	}

	private func shareHistorySummaryCard(entries: [RollHistoryEntry]) {
		let summary = viewModel.historySessionSummary(entries: entries)
		guard summary.rollCount > 0 else { return }
		let title = NSLocalizedString("history.summary.title", comment: "History summary card title")
		let body = String(
			format: NSLocalizedString("history.summary.body", comment: "History summary card body"),
			summary.rollCount,
			summary.totalDiceRolled,
			summary.topNotation ?? "-",
			summary.latestNotation ?? "-",
			summary.latestSum ?? 0
		)
		let footer = String(
			format: NSLocalizedString("history.summary.footer", comment: "History summary footer"),
			DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
		)
		let image = HistorySummaryCardRenderer().render(title: title, body: body, footer: footer)
		let activity = UIActivityViewController(activityItems: [image, body], applicationActivities: nil)
		if let popover = activity.popoverPresentationController {
			popover.barButtonItem = menuBarButtonItem
		}
		present(activity, animated: true)
	}

	@objc private func resetStats() {
		viewModel.resetStats()
		currentTotalsAccessibilityValue = NSLocalizedString("stats.reset", comment: "Stats reset confirmation")
		updateTotalsGraph(with: [])
	}

	private func updateTotalsText(outcome: RollOutcome) {
		currentTotalsAccessibilityValue = viewModel.formattedTotalsText(outcome: outcome)
		updateTotalsGraph(with: outcome.localTotals)
	}

	private func updateTotalsGraph(with counts: [Int]) {
		currentTotalsGraphCounts = counts
		let points = DiceRollDistributionChartData.points(from: counts)
		rollDistributionSheetController?.updateContent(
			title: NSLocalizedString("stats.graph.title", comment: "Stats graph title"),
			summary: currentTotalsAccessibilityValue,
			points: points,
			yAxisTitle: NSLocalizedString("stats.graph.yAxis", comment: "Graph y-axis title"),
			barColor: currentPalette.primaryTextColor,
			axisColor: currentPalette.secondaryTextColor,
			gridColor: UIColor.separator.withAlphaComponent(0.32),
			palette: currentPalette
		)
	}

	private func showValidationError(message: String) {
		navigationItem.prompt = message
		notationField.layer.borderColor = currentPalette.fieldBorderErrorColor.cgColor
		notationField.layer.borderWidth = 1
		notationField.layer.cornerRadius = 6
		let prefix = NSLocalizedString("alert.invalid.announcement", comment: "Accessibility announcement for invalid notation")
		UIAccessibility.post(notification: .announcement, argument: "\(prefix) \(message)")
		if viewModel.hapticsEnabled {
			hapticsEngine.playInvalidInput()
		}
	}

	private func clearValidationFeedback() {
		navigationItem.prompt = nil
		notationField.layer.borderWidth = 0
		notationField.layer.cornerRadius = 0
		notationField.layer.borderColor = UIColor.clear.cgColor
	}

	private func configureNotationInputAccessory() {
		let accessory = UIScrollView()
		accessory.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 44)
		accessory.showsHorizontalScrollIndicator = false
		accessory.alwaysBounceHorizontal = true
		accessory.backgroundColor = UIColor.secondarySystemBackground

		let stack = UIStackView()
		stack.axis = .horizontal
		stack.spacing = 6
		stack.alignment = .center
		stack.translatesAutoresizingMaskIntoConstraints = false
		accessory.addSubview(stack)

		NSLayoutConstraint.activate([
			stack.leadingAnchor.constraint(equalTo: accessory.leadingAnchor, constant: 10),
			stack.trailingAnchor.constraint(equalTo: accessory.trailingAnchor, constant: -10),
			stack.topAnchor.constraint(equalTo: accessory.topAnchor, constant: 5),
			stack.bottomAnchor.constraint(equalTo: accessory.bottomAnchor, constant: -5),
			stack.heightAnchor.constraint(equalTo: accessory.heightAnchor, constant: -10),
		])

		let tokens = ["d4", "d6", "d8", "d10", "d12", "d20", "+", "i"]
		for token in tokens {
			let button = makeAccessoryTokenButton(title: token)
			stack.addArrangedSubview(button)
		}
		stack.addArrangedSubview(makeAccessoryTokenButton(title: NSLocalizedString("toolbar.roll", comment: "Notation keyboard accessory roll action"), isPrimary: true, action: #selector(rollFromInput)))
		stack.addArrangedSubview(makeAccessoryTokenButton(title: NSLocalizedString("button.close", comment: "Close button title"), action: #selector(closeNotationAccessory)))
		notationField.inputAccessoryView = accessory
	}

	private func makeAccessoryTokenButton(title: String, isPrimary: Bool = false, action: Selector = #selector(insertNotationTokenButtonTapped(_:))) -> UIButton {
		let button = UIButton(type: .system)
		button.setTitle(title, for: .normal)
		button.titleLabel?.font = .systemFont(ofSize: 14, weight: isPrimary ? .semibold : .medium)
		button.setContentHuggingPriority(.required, for: .horizontal)
		button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
		button.backgroundColor = isPrimary ? UIColor.systemBlue : UIColor.tertiarySystemFill
		button.setTitleColor(isPrimary ? .white : .label, for: .normal)
		button.layer.cornerRadius = 8
		button.accessibilityIdentifier = "notationToken_\(title)"
		button.addTarget(self, action: action, for: .touchUpInside)
		return button
	}

	@objc private func insertNotationTokenButtonTapped(_ sender: UIButton) {
		guard let token = sender.currentTitle, !token.isEmpty else { return }
		insertNotationToken(token)
	}

	private func insertNotationToken(_ token: String) {
		if let selectedRange = notationField.selectedTextRange {
			notationField.replace(selectedRange, withText: token)
		} else {
			notationField.text = (notationField.text ?? "") + token
		}
		notationEditingChanged()
	}

	@objc private func closeNotationAccessory() {
		notationField.resignFirstResponder()
	}

	private func configurePointerInteractionsIfNeeded() {
		guard traitCollection.userInterfaceIdiom == .mac else { return }
		rollButton.isPointerInteractionEnabled = true
		showStatsButton.isPointerInteractionEnabled = true
	}

	private var shouldAnimateBoard: Bool {
		let sideCounts = viewModel.diceSideCounts
		return !sideCounts.isEmpty && viewModel.animationIntensity != .off
	}

	@objc private func showPresetPicker() {
		let picker = PresetPickerViewController(
			currentNotation: notationField.text ?? viewModel.configuration.notation,
			customPresets: viewModel.customPresets
		)
		picker.onSelectNotationPreset = { [weak self] notation in
			guard let self else { return }
			self.notationField.text = notation
			self.rollFromInput()
		}
		picker.onSaveCustomPresets = { [weak self] presets in
			self?.viewModel.saveCustomPresets(presets)
		}
		picker.onCreateCustomPreset = { [weak self] title, notation in
			guard let self else { return .failure(.invalidFormat) }
			return self.viewModel.createCustomPreset(title: title, notation: notation)
		}
		let navigationController = UINavigationController(rootViewController: picker)
		switch viewModel.theme {
		case .lightMode:
			navigationController.overrideUserInterfaceStyle = .light
		case .darkMode:
			navigationController.overrideUserInterfaceStyle = .dark
		case .system:
			navigationController.overrideUserInterfaceStyle = .unspecified
		}
		navigationController.modalPresentationStyle = .formSheet
		if let popover = navigationController.popoverPresentationController {
			popover.barButtonItem = presetsBarButtonItem
		}
		present(navigationController, animated: true)
	}

	private func updateControlMenu() {
		// Settings are presented via navigation bar menu button action.
	}

	@objc private func showControlSheet() {
		let sheet = DiceOptionsSheetViewController(
			state: DiceOptionsSheetViewController.State(
				animationsEnabled: viewModel.animationsEnabled,
				animationIntensity: viewModel.animationIntensity,
				theme: viewModel.theme,
				texture: viewModel.tableTexture,
				layout: viewModel.boardLayoutPreset,
				finish: viewModel.dieFinish,
				edgeOutlinesEnabled: viewModel.edgeOutlinesEnabled,
				motionBlurEnabled: viewModel.motionBlurEnabled,
				largeFaceLabelsEnabled: viewModel.largeFaceLabelsEnabled,
				soundPack: viewModel.soundPack,
				soundEffectsEnabled: viewModel.soundEffectsEnabled,
				hapticsEnabled: viewModel.hapticsEnabled
			)
		)
		sheet.onToggleAnimations = { [weak self] in self?.toggleAnimations() }
		sheet.onSetAnimationIntensity = { [weak self] intensity in self?.selectAnimationIntensity(intensity) }
		sheet.onSetTheme = { [weak self] theme in self?.selectTheme(theme) }
		sheet.onSetTexture = { [weak self] texture in self?.selectTexture(texture) }
		sheet.onSetLayout = { [weak self] preset in self?.selectBoardLayoutPreset(preset) }
		sheet.onSetFinish = { [weak self] finish in self?.selectDieFinish(finish) }
		sheet.onToggleEdgeOutlines = { [weak self] in self?.toggleEdgeOutlines() }
		sheet.onToggleMotionBlur = { [weak self] in self?.toggleMotionBlur() }
		sheet.onToggleLargeLabels = { [weak self] in self?.toggleLargeFaceLabels() }
		sheet.onSetSoundPack = { [weak self] pack in self?.selectSoundPack(pack) }
		sheet.onToggleSoundEffects = { [weak self] in self?.toggleSoundEffects() }
		sheet.onToggleHaptics = { [weak self] in self?.toggleHaptics() }
		sheet.onShowHistory = { [weak self, weak sheet] in
			guard let self else { return }
			sheet?.dismiss(animated: true) {
				self.showHistory()
			}
		}
		sheet.onResetVisuals = { [weak self, weak sheet] in
			guard let self else { return }
			sheet?.dismiss(animated: true) {
				self.confirmVisualReset()
			}
		}

		let navigationController = UINavigationController(rootViewController: sheet)
		switch viewModel.theme {
		case .lightMode:
			navigationController.overrideUserInterfaceStyle = .light
		case .darkMode:
			navigationController.overrideUserInterfaceStyle = .dark
		case .system:
			navigationController.overrideUserInterfaceStyle = .unspecified
		}
		navigationController.modalPresentationStyle = .formSheet
		if let popover = navigationController.popoverPresentationController {
			popover.barButtonItem = menuBarButtonItem
		}
		present(navigationController, animated: true)
	}

	@objc private func showRollDistributionSheet() {
		statsVisible = true
		UserDefaults.standard.set(true, forKey: statsVisibilityKey)
		updateStatsVisibility()
	}

	private func restoreStatsVisibility() {
		if UserDefaults.standard.object(forKey: statsVisibilityKey) != nil {
			statsVisible = UserDefaults.standard.bool(forKey: statsVisibilityKey)
		}
	}

	private func updateStatsVisibility() {
		guard isViewLoaded else { return }
		updateShowStatsButtonVisibility()
		guard view.window != nil else { return }
		if statsVisible {
			presentRollDistributionSheetIfNeeded()
		} else {
			pendingStatsSheetPresentation = false
			dismissRollDistributionSheetIfNeeded()
		}
	}

	private func presentRollDistributionSheetIfNeeded() {
		if rollDistributionSheetController != nil { return }
		guard presentedViewController == nil else {
			pendingStatsSheetPresentation = true
			return
		}
		pendingStatsSheetPresentation = false

		let sheet = RollDistributionSheetViewController()
		sheet.onDismiss = { [weak self] in
			guard let self else { return }
			self.rollDistributionSheetController = nil
			if self.statsVisible {
				self.statsVisible = false
				UserDefaults.standard.set(false, forKey: self.statsVisibilityKey)
				self.updateShowStatsButtonVisibility()
				self.updateControlMenu()
			}
		}
		switch viewModel.theme {
		case .lightMode:
			sheet.overrideUserInterfaceStyle = .light
		case .darkMode:
			sheet.overrideUserInterfaceStyle = .dark
		case .system:
			sheet.overrideUserInterfaceStyle = .unspecified
		}
		sheet.modalPresentationStyle = .pageSheet
		// Deliberate product decision: keep a compact fixed-height stats sheet.
		// This is intentionally constrained to avoid covering the board UI.
		let customDetent = UISheetPresentationController.Detent.custom(
			identifier: .init("fixedHeight")
		) { _ in
			return self.statsSheetHeight
		}
		if let presentationController = sheet.sheetPresentationController {
			presentationController.detents = [customDetent]
			presentationController.prefersGrabberVisible = true
			presentationController.preferredCornerRadius = 20
		}

		rollDistributionSheetController = sheet
		updateTotalsGraph(with: currentTotalsGraphCounts)
		present(sheet, animated: true)
	}

	private func dismissRollDistributionSheetIfNeeded() {
		guard let sheet = rollDistributionSheetController else { return }
		sheet.dismiss(animated: true)
		rollDistributionSheetController = nil
	}

	private func updateShowStatsButtonVisibility() {
		showStatsButton.isHidden = statsVisible
		updateRollButtonPosition(animated: view.window != nil)
	}

	private func updateRollButtonPosition(animated: Bool) {
		guard let rollButtonBottomConstraint else { return }
		let targetConstant: CGFloat
		if statsVisible {
			targetConstant = -(floatingControlBottomMargin + statsSheetHeight + rollButtonSpacingAboveStatsSheet)
		} else {
			targetConstant = -floatingControlBottomMargin
		}
		guard abs(rollButtonBottomConstraint.constant - targetConstant) > .ulpOfOne else { return }
		rollButtonBottomConstraint.constant = targetConstant
		guard animated else { return }
		UIView.animate(withDuration: 0.25) {
			self.view.layoutIfNeeded()
		}
	}

	private func selectTheme(_ theme: DiceTheme) {
		viewModel.setTheme(theme)
		applyTheme()
		updateControlMenu()
	}

	private func selectTexture(_ texture: DiceTableTexture) {
		viewModel.setTableTexture(texture)
		applyTexture()
		updateControlMenu()
	}

	private func selectBoardLayoutPreset(_ preset: DiceBoardLayoutPreset) {
		viewModel.setBoardLayoutPreset(preset)
		updateDiceBoard(animated: false)
		updateControlMenu()
	}

	private func selectDieFinish(_ finish: DiceDieFinish) {
		viewModel.setDieFinish(finish)
		currentDieFinish = finish
		diceBoardView.setDieFinish(finish)
		updateDiceBoard(animated: false)
		updateControlMenu()
	}

	private func toggleEdgeOutlines() {
		viewModel.setEdgeOutlinesEnabled(!viewModel.edgeOutlinesEnabled)
		diceBoardView.setEdgeOutlinesEnabled(viewModel.edgeOutlinesEnabled)
		updateDiceBoard(animated: false)
		updateControlMenu()
	}

	private func toggleMotionBlur() {
		viewModel.setMotionBlurEnabled(!viewModel.motionBlurEnabled)
		diceBoardView.setMotionBlurEnabled(viewModel.motionBlurEnabled)
		updateControlMenu()
	}

	private func selectSoundPack(_ pack: DiceSoundPack) {
		viewModel.setSoundPack(pack)
		syncSoundSettings()
		if pack != .off {
			playRollSound()
		}
		updateControlMenu()
	}

	private func toggleSoundEffects() {
		viewModel.setSoundEffectsEnabled(!viewModel.soundEffectsEnabled)
		syncSoundSettings()
		updateControlMenu()
	}

	private func toggleHaptics() {
		viewModel.setHapticsEnabled(!viewModel.hapticsEnabled)
		updateControlMenu()
		if viewModel.hapticsEnabled {
			hapticsEngine.playRollImpact()
		}
	}

	private func selectDieColorPreset(_ preset: DiceDieColorPreset, index: Int) {
		viewModel.applyPerDieColorSelection(preset, at: index)
		updateNotationField()
		diceBoardView.setDieColorPreferences(viewModel.dieColorPreferences)
		updateDiceBoard(animated: false)
		updateControlMenu()
		refreshDieInspectorIfVisible()
	}

	private func selectD6PipStyle(_ style: DiceD6PipStyle) {
		viewModel.setD6PipStyle(style)
		diceBoardView.setD6PipStyle(style)
		updateDiceBoard(animated: false)
		updateControlMenu()
		refreshDieInspectorIfVisible()
	}

	private func selectFaceNumeralFont(_ font: DiceFaceNumeralFont, dieIndex: Int? = nil) {
		if let dieIndex {
			viewModel.setFaceNumeralFont(font, forDieAt: dieIndex)
		} else {
			viewModel.setFaceNumeralFont(font)
			diceBoardView.setFaceNumeralFont(font)
		}
		updateDiceBoard(animated: false)
		updateControlMenu()
		refreshDieInspectorIfVisible()
	}

	private func toggleLargeFaceLabels() {
		viewModel.setLargeFaceLabelsEnabled(!viewModel.largeFaceLabelsEnabled)
		diceBoardView.setLargeFaceLabelsEnabled(viewModel.largeFaceLabelsEnabled)
		updateDiceBoard(animated: false)
		updateControlMenu()
	}

	private func confirmVisualReset() {
		let alert = UIAlertController(
			title: NSLocalizedString("alert.resetVisuals.title", comment: "Reset visual settings confirmation title"),
			message: NSLocalizedString("alert.resetVisuals.message", comment: "Reset visual settings confirmation message"),
			preferredStyle: .alert
		)
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.cancel", comment: "Cancel action"), style: .cancel))
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.reset", comment: "Reset button title"), style: .destructive) { [weak self] _ in
			self?.resetVisualPreferences()
		})
		present(alert, animated: true)
	}

	private func resetVisualPreferences() {
		viewModel.resetVisualPreferences()
		applyTheme()
		applyTexture()
		diceBoardView.setDieFinish(viewModel.dieFinish)
		diceBoardView.setEdgeOutlinesEnabled(viewModel.edgeOutlinesEnabled)
		diceBoardView.setDieColorPreferences(viewModel.dieColorPreferences)
		diceBoardView.setD6PipStyle(viewModel.d6PipStyle)
		diceBoardView.setFaceNumeralFont(viewModel.faceNumeralFont)
		diceBoardView.setLargeFaceLabelsEnabled(viewModel.largeFaceLabelsEnabled)
		diceBoardView.setAnimationIntensity(viewModel.animationIntensity)
		diceBoardView.setMotionBlurEnabled(viewModel.motionBlurEnabled)
		updateDiceBoard(animated: false)
		updateControlMenu()
	}

	private func applyTheme() {
		switch viewModel.theme {
		case .lightMode:
			overrideUserInterfaceStyle = .light
		case .darkMode:
			overrideUserInterfaceStyle = .dark
		case .system:
			overrideUserInterfaceStyle = .unspecified
		}
		let palette = viewModel.theme.palette
		currentPalette = palette
		currentTexture = viewModel.tableTexture
		currentDieFinish = viewModel.dieFinish
		view.backgroundColor = palette.screenBackgroundColor
		applyTexture()
		updateTotalsGraph(with: currentTotalsGraphCounts)
		notationField.textColor = palette.primaryTextColor
		notationField.keyboardAppearance = keyboardAppearance(for: viewModel.theme)
		let buttonColor = palette.primaryTextColor
		navigationController?.navigationBar.tintColor = buttonColor
		let navAppearance = UINavigationBarAppearance()
		navAppearance.configureWithOpaqueBackground()
		navAppearance.backgroundColor = palette.panelBackgroundColor
		navAppearance.titleTextAttributes = [.foregroundColor: buttonColor]
		navAppearance.largeTitleTextAttributes = [.foregroundColor: buttonColor]
		navigationController?.navigationBar.standardAppearance = navAppearance
		navigationController?.navigationBar.scrollEdgeAppearance = navAppearance
		navigationController?.navigationBar.compactAppearance = navAppearance
		if var rollButtonConfig = rollButton.configuration {
			rollButtonConfig.baseForegroundColor = buttonColor
			rollButtonConfig.baseBackgroundColor = palette.panelBackgroundColor.withAlphaComponent(0.92)
			rollButtonConfig.background.strokeColor = buttonColor.withAlphaComponent(0.25)
			rollButton.configuration = rollButtonConfig
		}
		if var showStatsButtonConfig = showStatsButton.configuration {
			showStatsButtonConfig.baseForegroundColor = buttonColor
			showStatsButtonConfig.baseBackgroundColor = palette.panelBackgroundColor.withAlphaComponent(0.92)
			showStatsButtonConfig.background.strokeColor = buttonColor.withAlphaComponent(0.25)
			showStatsButton.configuration = showStatsButtonConfig
		}
		diceBoardView.setDieFinish(currentDieFinish)
	}

	private func applyTexture() {
		currentTexture = viewModel.tableTexture
		diceBoardView.setTableTexture(currentTexture)
	}

	private func keyboardAppearance(for theme: DiceTheme) -> UIKeyboardAppearance {
		switch theme {
		case .lightMode:
			return .light
		case .darkMode:
			return .dark
		case .system:
			return traitCollection.userInterfaceStyle == .dark ? .dark : .light
		}
	}
}
