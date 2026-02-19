//
//  ViewController.swift
//  Dice
//
//  Created by Ben Wheatley on 2018/09/27.
//  Copyright © 2018 Ben Wheatley. All rights reserved.
//

import UIKit
import AVFoundation

private let reuseIdentifier = "DiceCell"

struct HistoryRowFormatter {
	static func subtitle(for entry: RollHistoryEntry, dateFormatter: DateFormatter) -> String {
		let time = String(
			format: NSLocalizedString("history.row.time", comment: "History row time label"),
			dateFormatter.string(from: entry.timestamp)
		)
		let values = String(
			format: NSLocalizedString("history.row.values", comment: "History row values label"),
			entry.values.map(String.init).joined(separator: ", ")
		)
		return "\(time) • \(values)"
	}
}

class DiceCollectionViewController: UICollectionViewController, UITextFieldDelegate {
	private let boardSupportedSides: Set<Int> = [4, 6, 8, 10, 12, 20]
	private let viewModel = DiceViewModel()
	private let soundEngine = DiceSoundEngine()

	private let notationField = UITextField()
	private let validationLabel = UILabel()
	private let totalsLabel = UILabel()
	private let totalsContainer = UIView()
	private let rollButton = UIButton(type: .system)
	private let presetsButton = UIButton(type: .system)
	private let menuButton = UIButton(type: .system)
	private let diceBoardView = DiceCubeView()
	private var controlsContainer: UIView?
	private var currentPalette = DiceTheme.system.palette
	private var currentTexture: DiceTableTexture = .neutral
	private var currentDieFinish: DiceDieFinish = .matte
	private let statsVisibilityKey = "Dice.showStats"
	private var statsVisible = true

	override func viewDidLoad() {
		super.viewDidLoad()
		viewModel.restore()
		syncSoundSettings()

		collectionView.keyboardDismissMode = .onDrag
		configureControls()
		configureDiceBoard()
		applyTheme()
		configurePointerInteractionsIfNeeded()
		updateNotationField()
		restoreStatsVisibility()
		updateStatsVisibility()
		updateControlMenu()
		performRoll()
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
		guard let controlsContainer else { return }
		let bottomInset = statsVisible ? totalsContainer.bounds.height + 16 : 8
		let insets = UIEdgeInsets(top: controlsContainer.bounds.height + 8, left: 0, bottom: bottomInset, right: 0)
		if collectionView.contentInset != insets {
			collectionView.contentInset = insets
			collectionView.scrollIndicatorInsets = insets
			collectionView.collectionViewLayout.invalidateLayout()
		}
		updateDiceBoard(animated: false)
	}

	override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		viewModel.diceValues.count
	}

	override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		guard let cell = collectionView.cellForItem(at: indexPath) else { return }
		presentDieOptions(for: indexPath.row, sourceView: cell)
	}

	override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! DiceCollectionViewCell
		let faceValue = viewModel.diceValues[indexPath.row]
		let sideCount = viewModel.diceSideCounts[indexPath.row]
		cell.configure(faceValue: faceValue, sideCount: sideCount, index: indexPath.row, palette: currentPalette, isLocked: viewModel.isDieLocked(at: indexPath.row))
		cell.onTapDie = { [weak self, weak cell] in
			guard let self, let cell else { return }
			self.presentDieOptions(for: indexPath.row, sourceView: cell)
		}
		cell.onToggleLock = { [weak self, weak collectionView] in
			guard let self else { return }
			self.viewModel.toggleDieLock(at: indexPath.row)
			collectionView?.reloadItems(at: [indexPath])
		}
		return cell
	}

	override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
		if event?.subtype == .motionShake {
			let outcome = viewModel.shakeToRoll()
			updateNotationField()
			updateTotalsText(outcome: outcome)
			collectionView.collectionViewLayout.invalidateLayout()
			collectionView.reloadData()
			collectionView.layoutIfNeeded()
			updateDiceBoard(animated: shouldAnimateBoard)
			playRollSound()
		}
	}

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		rollFromInput()
		return true
	}

	private func configureControls() {
		let controlsContainer = UIView()
		controlsContainer.translatesAutoresizingMaskIntoConstraints = false
		controlsContainer.backgroundColor = currentPalette.panelBackgroundColor
		controlsContainer.layer.cornerRadius = 10
		view.addSubview(controlsContainer)
		self.controlsContainer = controlsContainer

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

		rollButton.translatesAutoresizingMaskIntoConstraints = false
		rollButton.setTitle(NSLocalizedString("button.roll", comment: "Roll button title"), for: .normal)
		rollButton.addTarget(self, action: #selector(rollFromInput), for: .touchUpInside)
		rollButton.accessibilityLabel = NSLocalizedString("a11y.roll.label", comment: "Roll button accessibility label")
		rollButton.accessibilityIdentifier = "rollButton"
		rollButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
		rollButton.titleLabel?.adjustsFontForContentSizeCategory = true

		presetsButton.translatesAutoresizingMaskIntoConstraints = false
		presetsButton.setTitle(NSLocalizedString("button.presets", comment: "Presets button title"), for: .normal)
		presetsButton.addTarget(self, action: #selector(showPresetPicker), for: .touchUpInside)
		presetsButton.accessibilityLabel = NSLocalizedString("a11y.presets.label", comment: "Presets button accessibility label")
		presetsButton.accessibilityIdentifier = "presetsButton"
		presetsButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
		presetsButton.titleLabel?.adjustsFontForContentSizeCategory = true

		menuButton.translatesAutoresizingMaskIntoConstraints = false
		menuButton.setImage(UIImage(systemName: "line.3.horizontal"), for: .normal)
		menuButton.accessibilityLabel = NSLocalizedString("a11y.menu.label", comment: "Main menu accessibility label")
		menuButton.accessibilityIdentifier = "menuButton"
		menuButton.showsMenuAsPrimaryAction = true

		let row = UIStackView(arrangedSubviews: [notationField, rollButton, presetsButton, menuButton])
		row.translatesAutoresizingMaskIntoConstraints = false
		row.axis = .horizontal
		row.spacing = 8
		row.alignment = .fill

		validationLabel.translatesAutoresizingMaskIntoConstraints = false
		validationLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
		validationLabel.adjustsFontForContentSizeCategory = true
		validationLabel.textColor = currentPalette.validationColor
		validationLabel.numberOfLines = 2
		validationLabel.isHidden = true
		validationLabel.accessibilityTraits = .staticText
		validationLabel.accessibilityLabel = NSLocalizedString("a11y.validation.label", comment: "Validation message accessibility label")

		totalsContainer.translatesAutoresizingMaskIntoConstraints = false
		totalsContainer.backgroundColor = currentPalette.panelBackgroundColor
		totalsContainer.layer.cornerRadius = 10
		totalsContainer.layer.masksToBounds = true
		view.addSubview(totalsContainer)

		totalsLabel.translatesAutoresizingMaskIntoConstraints = false
		totalsLabel.backgroundColor = .clear
		totalsLabel.font = UIFont.preferredFont(forTextStyle: .body)
		totalsLabel.adjustsFontForContentSizeCategory = true
		totalsLabel.numberOfLines = 0
		totalsLabel.textColor = currentPalette.secondaryTextColor
		totalsLabel.textAlignment = .left
		totalsLabel.accessibilityIdentifier = "totalsLabel"
		totalsLabel.accessibilityLabel = NSLocalizedString("a11y.totals.label", comment: "Totals accessibility label")

		totalsContainer.addSubview(totalsLabel)

		controlsContainer.addSubview(row)
		controlsContainer.addSubview(validationLabel)

		NSLayoutConstraint.activate([
			controlsContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
			controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
			controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

			row.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 8),
			row.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 8),
			row.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -8),
			validationLabel.topAnchor.constraint(equalTo: row.bottomAnchor, constant: 6),
			validationLabel.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 10),
			validationLabel.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -10),
			validationLabel.bottomAnchor.constraint(equalTo: controlsContainer.bottomAnchor, constant: -8),

			totalsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
			totalsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
			totalsContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
			totalsContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 116),

			totalsLabel.leadingAnchor.constraint(equalTo: totalsContainer.leadingAnchor, constant: 8),
			totalsLabel.topAnchor.constraint(equalTo: totalsContainer.topAnchor, constant: 8),
			totalsLabel.bottomAnchor.constraint(equalTo: totalsContainer.bottomAnchor, constant: -8),
			totalsLabel.trailingAnchor.constraint(equalTo: totalsContainer.trailingAnchor, constant: -8),

			rollButton.widthAnchor.constraint(equalToConstant: 52),
			presetsButton.widthAnchor.constraint(equalToConstant: 72),
			menuButton.widthAnchor.constraint(equalToConstant: 44),
		])
	}

	private func configureDiceBoard() {
		diceBoardView.translatesAutoresizingMaskIntoConstraints = false
		diceBoardView.backgroundColor = .clear
		diceBoardView.isUserInteractionEnabled = false
		view.addSubview(diceBoardView)
		view.bringSubviewToFront(controlsContainer ?? UIView())
		view.bringSubviewToFront(totalsContainer)
		NSLayoutConstraint.activate([
			diceBoardView.leadingAnchor.constraint(equalTo: collectionView.leadingAnchor),
			diceBoardView.trailingAnchor.constraint(equalTo: collectionView.trailingAnchor),
			diceBoardView.topAnchor.constraint(equalTo: collectionView.topAnchor),
			diceBoardView.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor),
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
			collectionView.collectionViewLayout.invalidateLayout()
			collectionView.reloadData()
			collectionView.layoutIfNeeded()
			updateDiceBoard(animated: shouldAnimateBoard)
			playRollSound()
		case let .failure(error):
			showValidationError(message: error.userMessage)
		}
	}

	@objc private func repeatLastRoll() {
		let outcome = viewModel.repeatLastRoll()
		updateNotationField()
		clearValidationFeedback()
		updateTotalsText(outcome: outcome)
		collectionView.reloadData()
		collectionView.layoutIfNeeded()
		updateDiceBoard(animated: shouldAnimateBoard)
		playRollSound()
	}

	private func performRoll() {
		let outcome = viewModel.rollCurrent()
		updateNotationField()
		updateTotalsText(outcome: outcome)
		collectionView.collectionViewLayout.invalidateLayout()
		collectionView.reloadData()
		collectionView.layoutIfNeeded()
		updateDiceBoard(animated: shouldAnimateBoard)
		playRollSound()
	}

	private func presentDieOptions(for index: Int, sourceView: UIView) {
		guard viewModel.diceValues.indices.contains(index) else { return }
		guard viewModel.diceSideCounts.indices.contains(index) else { return }
		let sideCount = viewModel.diceSideCounts[index]
		let faceValue = viewModel.diceValues[index]
		let lockTitleKey = viewModel.isDieLocked(at: index) ? "die.options.unlock" : "die.options.lock"

		let alert = UIAlertController(
			title: String(format: NSLocalizedString("die.options.title", comment: "Per-die options title"), index + 1, sideCount),
			message: String(format: NSLocalizedString("die.options.message", comment: "Per-die options message"), faceValue),
			preferredStyle: .actionSheet
		)
		alert.addAction(UIAlertAction(title: NSLocalizedString("die.options.reroll", comment: "Reroll one die action"), style: .default) { [weak self] _ in
			self?.rerollDie(at: index)
		})
		alert.addAction(UIAlertAction(title: NSLocalizedString(lockTitleKey, comment: "Toggle lock action"), style: .default) { [weak self] _ in
			self?.toggleDieLock(at: index)
		})
		alert.addAction(UIAlertAction(title: NSLocalizedString("die.options.color", comment: "Change die color action"), style: .default) { [weak self] _ in
			self?.presentDieColorOptions(for: sideCount, sourceView: sourceView)
		})
		if sideCount == 6 {
			alert.addAction(UIAlertAction(title: NSLocalizedString("die.options.pips", comment: "Change d6 pip style action"), style: .default) { [weak self] _ in
				self?.presentD6PipStyleOptions(sourceView: sourceView)
			})
		} else {
			alert.addAction(UIAlertAction(title: NSLocalizedString("die.options.font", comment: "Change numeral font action"), style: .default) { [weak self] _ in
				self?.presentNumeralFontOptions(sourceView: sourceView)
			})
		}
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.cancel", comment: "Cancel action"), style: .cancel))
		if let popover = alert.popoverPresentationController {
			popover.sourceView = sourceView
			popover.sourceRect = sourceView.bounds
		}
		present(alert, animated: true)
	}

	private func presentDieColorOptions(for sideCount: Int, sourceView: UIView) {
		let alert = UIAlertController(
			title: String(format: NSLocalizedString("die.options.color.title", comment: "Die color sheet title"), sideCount),
			message: nil,
			preferredStyle: .actionSheet
		)
		for preset in DiceDieColorPreset.allCases {
			let isCurrent = viewModel.dieColorPreset(for: sideCount) == preset
			let marker = isCurrent ? " ✓" : ""
			let title = NSLocalizedString(preset.menuTitleKey, comment: "Die color option") + marker
			alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
				self?.selectDieColorPreset(preset, sideCount: sideCount)
			})
		}
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.cancel", comment: "Cancel action"), style: .cancel))
		if let popover = alert.popoverPresentationController {
			popover.sourceView = sourceView
			popover.sourceRect = sourceView.bounds
		}
		present(alert, animated: true)
	}

	private func presentD6PipStyleOptions(sourceView: UIView) {
		let alert = UIAlertController(
			title: NSLocalizedString("die.options.pips.title", comment: "D6 pip style sheet title"),
			message: nil,
			preferredStyle: .actionSheet
		)
		for style in DiceD6PipStyle.allCases {
			let isCurrent = viewModel.d6PipStyle == style
			let marker = isCurrent ? " ✓" : ""
			let title = NSLocalizedString(style.menuTitleKey, comment: "D6 pip style option") + marker
			alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
				self?.selectD6PipStyle(style)
			})
		}
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.cancel", comment: "Cancel action"), style: .cancel))
		if let popover = alert.popoverPresentationController {
			popover.sourceView = sourceView
			popover.sourceRect = sourceView.bounds
		}
		present(alert, animated: true)
	}

	private func presentNumeralFontOptions(sourceView: UIView) {
		let alert = UIAlertController(
			title: NSLocalizedString("die.options.font.title", comment: "Numeral font sheet title"),
			message: nil,
			preferredStyle: .actionSheet
		)
		for font in DiceFaceNumeralFont.allCases {
			let isCurrent = viewModel.faceNumeralFont == font
			let marker = isCurrent ? " ✓" : ""
			let title = NSLocalizedString(font.menuTitleKey, comment: "Numeral font option") + marker
			alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
				self?.selectFaceNumeralFont(font)
			})
		}
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.cancel", comment: "Cancel action"), style: .cancel))
		if let popover = alert.popoverPresentationController {
			popover.sourceView = sourceView
			popover.sourceRect = sourceView.bounds
		}
		present(alert, animated: true)
	}

	private func rerollDie(at index: Int) {
		guard let outcome = viewModel.rerollDie(at: index) else { return }
		updateTotalsText(outcome: outcome)
		collectionView.reloadItems(at: [IndexPath(row: index, section: 0)])
		collectionView.layoutIfNeeded()
		updateDiceBoard(animated: shouldAnimateBoard)
		playRollSound()
	}

	private func toggleDieLock(at index: Int) {
		viewModel.toggleDieLock(at: index)
		collectionView.reloadItems(at: [IndexPath(row: index, section: 0)])
	}

	private func updateDiceBoard(animated: Bool) {
		let sideCounts = viewModel.diceSideCounts
		guard !sideCounts.isEmpty,
			  sideCounts.allSatisfy({ boardSupportedSides.contains($0) }) else {
			diceBoardView.isHidden = true
			return
		}

		diceBoardView.isHidden = false
		diceBoardView.setDieFinish(viewModel.dieFinish)
		diceBoardView.setEdgeOutlinesEnabled(viewModel.edgeOutlinesEnabled)
		diceBoardView.setDieColorPreferences(viewModel.dieColorPreferences)
		diceBoardView.setD6PipStyle(viewModel.d6PipStyle)
		diceBoardView.setFaceNumeralFont(viewModel.faceNumeralFont)
		diceBoardView.setAnimationIntensity(viewModel.animationIntensity)
		diceBoardView.setMotionBlurEnabled(viewModel.motionBlurEnabled)

		let mixed = Set(sideCounts).count > 1
		let baseScale: CGFloat
		switch viewModel.boardLayoutPreset {
		case .compact:
			baseScale = mixed ? 0.24 : 0.27
		case .spacious:
			baseScale = mixed ? 0.19 : 0.22
		}
		let sideLength = baseScale * min(collectionView.bounds.width, collectionView.bounds.height)
		let itemCount = collectionView.numberOfItems(inSection: 0)
		var centers: [CGPoint] = []
		var values: [Int] = []
		var boardSideCounts: [Int] = []
		centers.reserveCapacity(itemCount)
		values.reserveCapacity(itemCount)
		boardSideCounts.reserveCapacity(itemCount)

		for row in 0..<itemCount {
			let indexPath = IndexPath(row: row, section: 0)
			let cellFrame: CGRect
			if let attrs = collectionView.layoutAttributesForItem(at: indexPath) {
				cellFrame = attrs.frame
			} else {
				continue
			}
			let visibleCenter = CGPoint(
				x: cellFrame.midX - collectionView.contentOffset.x,
				y: cellFrame.midY - collectionView.contentOffset.y
			)
			let centerInBoard = diceBoardView.convert(visibleCenter, from: collectionView)
			centers.append(centerInBoard)
			values.append(viewModel.diceValues[row])
			boardSideCounts.append(sideCounts[row])
		}

		diceBoardView.setDice(values: values, centers: centers, sideLength: sideLength, sideCounts: boardSideCounts, animated: animated)
	}

	private func showInvalidNotationAlert(message: String) {
		let alert = UIAlertController(
			title: NSLocalizedString("alert.invalid.title", comment: "Invalid notation alert title"),
			message: message,
			preferredStyle: .alert
		)
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.ok", comment: "Generic confirmation button"), style: .default))
		present(alert, animated: true)
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
		soundEngine.configure(pack: viewModel.soundPack, volume: viewModel.soundVolume)
	}

	private func playRollSound() {
		soundEngine.playRollImpact()
	}

	private func selectAnimationIntensity(_ intensity: DiceAnimationIntensity) {
		viewModel.setAnimationIntensity(intensity)
		diceBoardView.setAnimationIntensity(intensity)
		updateControlMenu()
	}

	@objc private func showHistory() {
		let historyViewController = RollHistoryViewController(entries: viewModel.historyEntries)
		historyViewController.onExportText = { [weak self] in
			guard let self else { return }
			self.presentExportSheet(content: self.viewModel.exportHistory(format: .text), filename: "dice-history.txt")
		}
		historyViewController.onExportCSV = { [weak self] in
			guard let self else { return }
			self.presentExportSheet(content: self.viewModel.exportHistory(format: .csv), filename: "dice-history.csv")
		}
		historyViewController.onClearHistory = { [weak self, weak historyViewController] in
			guard let self else { return }
			self.viewModel.clearHistory()
			historyViewController?.updateEntries([])
		}
		let navigationController = UINavigationController(rootViewController: historyViewController)
		navigationController.modalPresentationStyle = .formSheet
		if let popover = navigationController.popoverPresentationController {
			popover.sourceView = menuButton
			popover.sourceRect = menuButton.bounds
		}
		present(navigationController, animated: true)
	}

	private func presentExportSheet(content: String, filename: String) {
		let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
		do {
			try content.write(to: temporaryURL, atomically: true, encoding: .utf8)
			let activity = UIActivityViewController(activityItems: [temporaryURL], applicationActivities: nil)
			if let popover = activity.popoverPresentationController {
				popover.sourceView = menuButton
				popover.sourceRect = menuButton.bounds
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

	@objc private func resetStats() {
		viewModel.resetStats()
		totalsLabel.text = "  \(NSLocalizedString("stats.reset", comment: "Stats reset confirmation"))"
	}

	private func updateTotalsText(outcome: RollOutcome) {
		totalsLabel.text = viewModel.formattedTotalsText(outcome: outcome, boardSupportedSides: boardSupportedSides)
	}

	private func showValidationError(message: String) {
		validationLabel.text = message
		validationLabel.isHidden = false
		notationField.layer.borderColor = currentPalette.fieldBorderErrorColor.cgColor
		notationField.layer.borderWidth = 1
		notationField.layer.cornerRadius = 6
		let prefix = NSLocalizedString("alert.invalid.announcement", comment: "Accessibility announcement for invalid notation")
		UIAccessibility.post(notification: .announcement, argument: "\(prefix) \(message)")
	}

	private func clearValidationFeedback() {
		validationLabel.isHidden = true
		validationLabel.text = nil
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
		for control in [rollButton, presetsButton, menuButton] {
			control.isPointerInteractionEnabled = true
		}
	}

	private var shouldAnimateBoard: Bool {
		let sideCounts = viewModel.diceSideCounts
		return !sideCounts.isEmpty && sideCounts.allSatisfy({ boardSupportedSides.contains($0) }) && viewModel.animationIntensity != .off
	}

	@objc private func showPresetPicker() {
		let picker = PresetPickerViewController(
			currentNotation: notationField.text ?? viewModel.configuration.notation,
			customPresets: viewModel.customPresets
		)
		picker.onSelectPreset = { [weak self] diceCount, intuitive in
			self?.applyPreset(diceCount: diceCount, intuitive: intuitive)
		}
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
		navigationController.modalPresentationStyle = .formSheet
		if let popover = navigationController.popoverPresentationController {
			popover.sourceView = presetsButton
			popover.sourceRect = presetsButton.bounds
		}
		present(navigationController, animated: true)
	}

	private func applyPreset(diceCount: Int, intuitive: Bool) {
		let outcome = viewModel.selectPreset(diceCount: diceCount, intuitive: intuitive)
		updateNotationField()
		clearValidationFeedback()
		updateTotalsText(outcome: outcome)
		collectionView.reloadData()
		collectionView.layoutIfNeeded()
		updateDiceBoard(animated: shouldAnimateBoard)
		playRollSound()
	}

	@objc private func showControlMenu() {
		updateControlMenu()
	}

	private func updateControlMenu() {
		let animationAction = UIAction(
			title: NSLocalizedString("menu.control.animations", comment: "Animations toggle menu title"),
			state: viewModel.animationsEnabled ? .on : .off
		) { [weak self] _ in
			self?.toggleAnimations()
		}
		let animationIntensityActions = DiceAnimationIntensity.allCases.map { intensity in
			UIAction(
				title: NSLocalizedString(intensity.menuTitleKey, comment: "Animation intensity option"),
				state: viewModel.animationIntensity == intensity ? .on : .off
			) { [weak self] _ in
				self?.selectAnimationIntensity(intensity)
			}
		}
		let animationIntensityMenu = UIMenu(
			title: NSLocalizedString("menu.control.animationIntensity", comment: "Animation intensity submenu title"),
			options: .displayInline,
			children: animationIntensityActions
		)
		let statsAction = UIAction(
			title: NSLocalizedString("menu.control.showStats", comment: "Show stats toggle menu title"),
			state: statsVisible ? .on : .off
		) { [weak self] _ in
			self?.toggleStatsVisibility()
		}
		let historyAction = UIAction(title: NSLocalizedString("button.history", comment: "History button title")) { [weak self] _ in
			self?.showHistory()
		}
		let repeatAction = UIAction(title: NSLocalizedString("menu.control.repeatLast", comment: "Repeat last roll menu title")) { [weak self] _ in
			self?.repeatLastRoll()
		}
		let themeActions = DiceTheme.allCases.map { theme in
			UIAction(
				title: NSLocalizedString(theme.menuTitleKey, comment: "Theme option title"),
				state: self.viewModel.theme == theme ? .on : .off
			) { [weak self] _ in
				self?.selectTheme(theme)
			}
		}
		let themeMenu = UIMenu(
			title: NSLocalizedString("menu.control.theme", comment: "Theme submenu title"),
			options: .displayInline,
			children: themeActions
		)
		let textureActions = DiceTableTexture.allCases.map { texture in
			UIAction(
				title: NSLocalizedString(texture.menuTitleKey, comment: "Table texture option"),
				state: self.viewModel.tableTexture == texture ? .on : .off
			) { [weak self] _ in
				self?.selectTexture(texture)
			}
		}
		let textureMenu = UIMenu(
			title: NSLocalizedString("menu.control.texture", comment: "Texture submenu title"),
			options: .displayInline,
			children: textureActions
		)
		let layoutActions = DiceBoardLayoutPreset.allCases.map { preset in
			UIAction(
				title: NSLocalizedString(preset.menuTitleKey, comment: "Board layout preset option"),
				state: viewModel.boardLayoutPreset == preset ? .on : .off
			) { [weak self] _ in
				self?.selectBoardLayoutPreset(preset)
			}
		}
		let layoutMenu = UIMenu(
			title: NSLocalizedString("menu.control.layout", comment: "Layout submenu title"),
			options: .displayInline,
			children: layoutActions
		)
		let finishActions = DiceDieFinish.allCases.map { finish in
			UIAction(
				title: NSLocalizedString(finish.menuTitleKey, comment: "Die finish option"),
				state: self.viewModel.dieFinish == finish ? .on : .off
			) { [weak self] _ in
				self?.selectDieFinish(finish)
			}
		}
		let finishMenu = UIMenu(
			title: NSLocalizedString("menu.control.finish", comment: "Die finish submenu title"),
			options: .displayInline,
			children: finishActions
		)
		let outlinesAction = UIAction(
			title: NSLocalizedString("menu.control.edgeOutlines", comment: "Edge outlines toggle menu title"),
			state: viewModel.edgeOutlinesEnabled ? .on : .off
		) { [weak self] _ in
			self?.toggleEdgeOutlines()
		}
		let motionBlurAction = UIAction(
			title: NSLocalizedString("menu.control.motionBlur", comment: "Motion blur toggle menu title"),
			state: viewModel.motionBlurEnabled ? .on : .off
		) { [weak self] _ in
			self?.toggleMotionBlur()
		}
		let soundPackActions = DiceSoundPack.allCases.map { pack in
			UIAction(
				title: NSLocalizedString(pack.menuTitleKey, comment: "Sound pack option"),
				state: self.viewModel.soundPack == pack ? .on : .off
			) { [weak self] _ in
				self?.selectSoundPack(pack)
			}
		}
		let soundPackMenu = UIMenu(
			title: NSLocalizedString("menu.control.soundPack", comment: "Sound pack submenu title"),
			options: .displayInline,
			children: soundPackActions
		)
		let soundVolumeAction = UIAction(
			title: String(
				format: NSLocalizedString("menu.control.soundVolume", comment: "Sound volume menu title"),
				Int((viewModel.soundVolume * 100).rounded())
			)
		) { [weak self] _ in
			self?.presentSoundVolumeSheet()
		}
		let previewStyleAction = UIAction(title: NSLocalizedString("menu.control.previewStyle", comment: "Preview style action title")) { [weak self] _ in
			self?.presentStylePreview()
		}
		let resetVisualsAction = UIAction(
			title: NSLocalizedString("menu.control.resetVisuals", comment: "Reset visual settings menu title"),
			attributes: .destructive
		) { [weak self] _ in
			self?.confirmVisualReset()
		}
		let resetAction = UIAction(title: NSLocalizedString("button.reset", comment: "Reset button title"), attributes: .destructive) { [weak self] _ in
			self?.resetStats()
		}
		menuButton.menu = UIMenu(children: [historyAction, repeatAction, animationAction, animationIntensityMenu, soundPackMenu, soundVolumeAction, resetAction, statsAction, themeMenu, textureMenu, layoutMenu, finishMenu, outlinesAction, motionBlurAction, previewStyleAction, resetVisualsAction])
	}

	@objc private func toggleStatsVisibility() {
		statsVisible.toggle()
		UserDefaults.standard.set(statsVisible, forKey: statsVisibilityKey)
		updateStatsVisibility()
		updateControlMenu()
	}

	private func restoreStatsVisibility() {
		if UserDefaults.standard.object(forKey: statsVisibilityKey) != nil {
			statsVisible = UserDefaults.standard.bool(forKey: statsVisibilityKey)
		}
	}

	private func updateStatsVisibility() {
		totalsContainer.isHidden = !statsVisible
		view.setNeedsLayout()
		view.layoutIfNeeded()
	}

	private func selectTheme(_ theme: DiceTheme) {
		viewModel.setTheme(theme)
		applyTheme()
		collectionView.reloadData()
		updateControlMenu()
	}

	private func selectTexture(_ texture: DiceTableTexture) {
		viewModel.setTableTexture(texture)
		applyTexture()
		updateControlMenu()
	}

	private func selectBoardLayoutPreset(_ preset: DiceBoardLayoutPreset) {
		viewModel.setBoardLayoutPreset(preset)
		collectionView.collectionViewLayout.invalidateLayout()
		collectionView.reloadData()
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

	private func presentSoundVolumeSheet() {
		let alert = UIAlertController(
			title: NSLocalizedString("alert.soundVolume.title", comment: "Sound volume sheet title"),
			message: "\n\n\n",
			preferredStyle: .alert
		)
		let slider = UISlider(frame: .zero)
		slider.minimumValue = 0
		slider.maximumValue = 1
		slider.value = viewModel.soundVolume
		slider.translatesAutoresizingMaskIntoConstraints = false
		alert.view.addSubview(slider)

		NSLayoutConstraint.activate([
			slider.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor, constant: 20),
			slider.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor, constant: -20),
			slider.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 74),
		])

		alert.addAction(UIAlertAction(title: NSLocalizedString("button.cancel", comment: "Cancel action"), style: .cancel))
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.save", comment: "Save button title"), style: .default) { [weak self] _ in
			guard let self else { return }
			viewModel.setSoundVolume(slider.value)
			syncSoundSettings()
			updateControlMenu()
		})
		present(alert, animated: true)
	}

	private func selectDieColorPreset(_ preset: DiceDieColorPreset, sideCount: Int) {
		viewModel.setDieColorPreset(preset, for: sideCount)
		diceBoardView.setDieColorPreferences(viewModel.dieColorPreferences)
		updateDiceBoard(animated: false)
		updateControlMenu()
	}

	private func selectD6PipStyle(_ style: DiceD6PipStyle) {
		viewModel.setD6PipStyle(style)
		diceBoardView.setD6PipStyle(style)
		updateDiceBoard(animated: false)
		updateControlMenu()
	}

	private func selectFaceNumeralFont(_ font: DiceFaceNumeralFont) {
		viewModel.setFaceNumeralFont(font)
		diceBoardView.setFaceNumeralFont(font)
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
		diceBoardView.setAnimationIntensity(viewModel.animationIntensity)
		diceBoardView.setMotionBlurEnabled(viewModel.motionBlurEnabled)
		updateDiceBoard(animated: false)
		updateControlMenu()
	}

	private func presentStylePreview() {
		let previewState = DiceStylePreviewState(
			theme: viewModel.theme,
			texture: viewModel.tableTexture,
			dieFinish: viewModel.dieFinish,
			edgeOutlinesEnabled: viewModel.edgeOutlinesEnabled,
			dieColors: viewModel.dieColorPreferences,
			d6PipStyle: viewModel.d6PipStyle,
			faceNumeralFont: viewModel.faceNumeralFont
		)
		let preview = DiceStylePreviewViewController(state: previewState)
		let navigation = UINavigationController(rootViewController: preview)
		navigation.modalPresentationStyle = .formSheet
		if let popover = navigation.popoverPresentationController {
			popover.sourceView = menuButton
			popover.sourceRect = menuButton.bounds
		}
		present(navigation, animated: true)
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
		controlsContainer?.backgroundColor = palette.panelBackgroundColor
		totalsContainer.backgroundColor = palette.panelBackgroundColor
		totalsLabel.textColor = palette.secondaryTextColor
		validationLabel.textColor = palette.validationColor
		notationField.textColor = palette.primaryTextColor
		notationField.keyboardAppearance = keyboardAppearance(for: viewModel.theme)
		let buttonColor = palette.primaryTextColor
		rollButton.setTitleColor(buttonColor, for: .normal)
		presetsButton.setTitleColor(buttonColor, for: .normal)
		menuButton.tintColor = buttonColor
		diceBoardView.setDieFinish(currentDieFinish)
	}

	private func applyTexture() {
		currentTexture = viewModel.tableTexture
		collectionView.backgroundColor = DiceTextureProvider.shared.patternColor(for: currentTexture)
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

private final class DiceSoundEngine {
	private let engine = AVAudioEngine()
	private let player = AVAudioPlayerNode()
	private var cachedBuffers: [DiceSoundPack: AVAudioPCMBuffer] = [:]
	private var currentPack: DiceSoundPack = .off
	private var currentVolume: Float = 0.65
	private var didStartEngine = false

	init() {
		engine.attach(player)
		engine.connect(player, to: engine.mainMixerNode, format: nil)
	}

	func configure(pack: DiceSoundPack, volume: Float) {
		currentPack = pack
		currentVolume = min(max(volume, 0), 1)
	}

	func playRollImpact() {
		guard currentPack != .off else { return }
		guard currentVolume > 0 else { return }
		ensureEngineStarted()
		guard let buffer = buffer(for: currentPack) else { return }
		player.volume = currentVolume
		player.scheduleBuffer(buffer, at: nil, options: []) { }
		if !player.isPlaying {
			player.play()
		}
	}

	private func ensureEngineStarted() {
		guard !didStartEngine else { return }
		do {
			try engine.start()
			didStartEngine = true
		} catch {
			didStartEngine = false
		}
	}

	private func buffer(for pack: DiceSoundPack) -> AVAudioPCMBuffer? {
		if let cached = cachedBuffers[pack] {
			return cached
		}
		guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else {
			return nil
		}
		let frameCount: AVAudioFrameCount = 7_000
		guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
			return nil
		}
		buffer.frameLength = frameCount
		guard let channel = buffer.floatChannelData?.pointee else {
			return nil
		}
		fill(channel: channel, count: Int(frameCount), sampleRate: Float(format.sampleRate), pack: pack)
		cachedBuffers[pack] = buffer
		return buffer
	}

	private func fill(channel: UnsafeMutablePointer<Float>, count: Int, sampleRate: Float, pack: DiceSoundPack) {
		let twoPi = Float.pi * 2
		var lpState: Float = 0
		for index in 0..<count {
			let t = Float(index) / sampleRate
			let envelope = exp(-12 * t)
			let noise = Float.random(in: -1...1)
			let x: Float
			switch pack {
			case .off:
				x = 0
			case .softWood:
				let tone = sin(twoPi * 230 * t)
				let mixed = (0.6 * noise) + (0.4 * tone)
				lpState += 0.08 * (mixed - lpState)
				x = lpState * envelope * 0.65
			case .hardTable:
				let tone = sin(twoPi * 1_350 * t)
				let mixed = (0.82 * noise) + (0.18 * tone)
				lpState += 0.03 * (mixed - lpState)
				let hp = mixed - lpState
				x = hp * envelope * 0.9
			}
			channel[index] = max(-1, min(1, x))
		}
	}
}

private final class PresetPickerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
	var onSelectPreset: ((Int, Bool) -> Void)?
	var onSelectNotationPreset: ((String) -> Void)?
	var onSaveCustomPresets: (([DiceSavedPreset]) -> Void)?
	var onCreateCustomPreset: ((String, String) -> Result<Void, DiceInputError>)?

	private let normalTableView = UITableView(frame: .zero, style: .insetGrouped)
	private let intuitiveTableView = UITableView(frame: .zero, style: .insetGrouped)
	private let currentNotation: String
	private var customPresets: [DiceSavedPreset]

	init(currentNotation: String, customPresets: [DiceSavedPreset]) {
		self.currentNotation = currentNotation
		self.customPresets = customPresets
		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("menu.presets.title", comment: "Preset menu title")
		view.backgroundColor = .systemBackground
		navigationItem.leftBarButtonItem = UIBarButtonItem(
			title: NSLocalizedString("button.close", comment: "Close button title"),
			style: .plain,
			target: self,
			action: #selector(close)
		)
		navigationItem.rightBarButtonItem = UIBarButtonItem(
			title: NSLocalizedString("button.manage", comment: "Manage presets button title"),
			style: .plain,
			target: self,
			action: #selector(openPresetManager)
		)
		configureTableView(normalTableView, intuitive: false)
		configureTableView(intuitiveTableView, intuitive: true)

		let stack = UIStackView(arrangedSubviews: [normalTableView, intuitiveTableView])
		stack.axis = .horizontal
		stack.spacing = 8
		stack.distribution = .fillEqually
		stack.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(stack)

		NSLayoutConstraint.activate([
			stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			normalTableView.widthAnchor.constraint(equalTo: intuitiveTableView.widthAnchor),
		])

		preferredContentSize = CGSize(width: 420, height: 420)
	}

	private func configureTableView(_ tableView: UITableView, intuitive: Bool) {
		tableView.dataSource = self
		tableView.delegate = self
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PresetCell")
		tableView.accessibilityIdentifier = intuitive ? "intuitivePresetsTable" : "normalPresetsTable"
		tableView.tag = intuitive ? 1 : 0
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		10
	}

	func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		tableView.tag == 0
			? NSLocalizedString("menu.presets.normal", comment: "Normal presets section title")
			: NSLocalizedString("menu.presets.intuitive", comment: "Intuitive presets section title")
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "PresetCell", for: indexPath)
		let diceCount = indexPath.row + 1
		let intuitive = tableView.tag == 1
		cell.textLabel?.text = intuitive ? "\(diceCount)d6i" : "\(diceCount)d6"
		cell.accessibilityIdentifier = intuitive ? "preset_\(diceCount)d6i" : "preset_\(diceCount)d6"
		return cell
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let diceCount = indexPath.row + 1
		let intuitive = tableView.tag == 1
		onSelectPreset?(diceCount, intuitive)
		dismiss(animated: true)
	}

	@objc private func openPresetManager() {
		let manager = PresetManagerViewController(
			initialPresets: customPresets,
			currentNotation: currentNotation
		)
		manager.onSave = { [weak self] presets in
			guard let self else { return }
			customPresets = presets
			onSaveCustomPresets?(presets)
		}
		manager.onCreatePreset = { [weak self] title, notation in
			guard let self else { return .failure(.invalidFormat) }
			return onCreateCustomPreset?(title, notation) ?? .failure(.invalidFormat)
		}
		manager.onApplyPreset = { [weak self] notation in
			self?.onSelectNotationPreset?(notation)
			self?.dismiss(animated: true)
		}
		navigationController?.pushViewController(manager, animated: true)
	}

	@objc private func close() {
		dismiss(animated: true)
	}
}

private final class PresetManagerViewController: UITableViewController {
	var onSave: (([DiceSavedPreset]) -> Void)?
	var onApplyPreset: ((String) -> Void)?
	var onCreatePreset: ((String, String) -> Result<Void, DiceInputError>)?

	private var presets: [DiceSavedPreset]
	private let currentNotation: String

	init(initialPresets: [DiceSavedPreset], currentNotation: String) {
		self.presets = initialPresets
		self.currentNotation = currentNotation
		super.init(style: .insetGrouped)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("presets.manage.title", comment: "Preset manager title")
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ManagedPresetCell")
		navigationItem.rightBarButtonItems = [
			UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addPreset)),
			editButtonItem
		]
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		onSave?(presets)
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		presets.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "ManagedPresetCell", for: indexPath)
		let preset = presets[indexPath.row]
		var config = UIListContentConfiguration.subtitleCell()
		config.text = "\(preset.pinned ? "★ " : "")\(preset.title)"
		config.secondaryText = preset.notation
		cell.contentConfiguration = config
		cell.accessibilityIdentifier = "managedPreset_\(preset.id)"
		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		onApplyPreset?(presets[indexPath.row].notation)
	}

	override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
		true
	}

	override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
		let moved = presets.remove(at: sourceIndexPath.row)
		presets.insert(moved, at: destinationIndexPath.row)
	}

	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		let rename = UIContextualAction(style: .normal, title: NSLocalizedString("button.rename", comment: "Rename button title")) { [weak self] _, _, done in
			self?.renamePreset(at: indexPath.row)
			done(true)
		}
		rename.backgroundColor = .systemBlue

		let delete = UIContextualAction(style: .destructive, title: NSLocalizedString("button.delete", comment: "Delete button title")) { [weak self] _, _, done in
			self?.presets.remove(at: indexPath.row)
			tableView.deleteRows(at: [indexPath], with: .automatic)
			done(true)
		}
		return UISwipeActionsConfiguration(actions: [delete, rename])
	}

	override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		let title = presets[indexPath.row].pinned
			? NSLocalizedString("button.unpin", comment: "Unpin button title")
			: NSLocalizedString("button.pin", comment: "Pin button title")
		let pin = UIContextualAction(style: .normal, title: title) { [weak self] _, _, done in
			guard let self else { return }
			presets[indexPath.row].pinned.toggle()
			tableView.reloadRows(at: [indexPath], with: .automatic)
			done(true)
		}
		pin.backgroundColor = .systemOrange
		return UISwipeActionsConfiguration(actions: [pin])
	}

	@objc private func addPreset() {
		let alert = UIAlertController(
			title: NSLocalizedString("presets.manage.add.title", comment: "Add preset dialog title"),
			message: NSLocalizedString("presets.manage.add.message", comment: "Add preset dialog message"),
			preferredStyle: .alert
		)
		alert.addTextField { field in
			field.placeholder = NSLocalizedString("presets.manage.field.title", comment: "Preset title field placeholder")
		}
		alert.addTextField { field in
			field.placeholder = NSLocalizedString("presets.manage.field.notation", comment: "Preset notation field placeholder")
			field.text = self.currentNotation
			field.autocapitalizationType = .none
			field.autocorrectionType = .no
		}
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.cancel", comment: "Cancel action"), style: .cancel))
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.save", comment: "Save button title"), style: .default) { [weak self, weak alert] _ in
			guard let self, let fields = alert?.textFields, fields.count == 2 else { return }
			let rawTitle = fields[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
			let notation = fields[1].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
			let title = rawTitle.isEmpty ? notation : rawTitle
			guard !title.isEmpty, !notation.isEmpty else { return }
			switch self.onCreatePreset?(title, notation) ?? .success(()) {
			case .success:
				self.presets.append(DiceSavedPreset(title: title, notation: notation))
				self.tableView.reloadData()
			case .failure(let error):
				self.presentInlineError(error.userMessage)
			}
		})
		present(alert, animated: true)
	}

	private func renamePreset(at index: Int) {
		guard presets.indices.contains(index) else { return }
		let alert = UIAlertController(
			title: NSLocalizedString("presets.manage.rename.title", comment: "Rename preset dialog title"),
			message: nil,
			preferredStyle: .alert
		)
		alert.addTextField { field in
			field.text = self.presets[index].title
		}
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.cancel", comment: "Cancel action"), style: .cancel))
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.save", comment: "Save button title"), style: .default) { [weak self, weak alert] _ in
			guard let self, let text = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
			presets[index].title = text
			tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
		})
		present(alert, animated: true)
	}

	private func presentInlineError(_ message: String) {
		let alert = UIAlertController(title: NSLocalizedString("alert.invalid.title", comment: "Invalid notation alert title"), message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.ok", comment: "Generic confirmation button"), style: .default))
		present(alert, animated: true)
	}
}

private struct DiceStylePreviewState {
	let theme: DiceTheme
	let texture: DiceTableTexture
	let dieFinish: DiceDieFinish
	let edgeOutlinesEnabled: Bool
	let dieColors: DiceDieColorPreferences
	let d6PipStyle: DiceD6PipStyle
	let faceNumeralFont: DiceFaceNumeralFont
}

private final class DiceStylePreviewViewController: UIViewController {
	private let state: DiceStylePreviewState
	private let previewBoard = DiceCubeView()
	private let summaryLabel = UILabel()

	init(state: DiceStylePreviewState) {
		self.state = state
		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("preview.title", comment: "Style preview screen title")
		navigationItem.leftBarButtonItem = UIBarButtonItem(
			title: NSLocalizedString("button.close", comment: "Close button title"),
			style: .plain,
			target: self,
			action: #selector(close)
		)

		let palette = state.theme.palette
		view.backgroundColor = palette.screenBackgroundColor

		let texturePanel = UIView()
		texturePanel.translatesAutoresizingMaskIntoConstraints = false
		texturePanel.backgroundColor = DiceTextureProvider.shared.patternColor(for: state.texture)
		texturePanel.layer.cornerRadius = 12
		texturePanel.clipsToBounds = true

		previewBoard.translatesAutoresizingMaskIntoConstraints = false
		previewBoard.setDieFinish(state.dieFinish)
		previewBoard.setEdgeOutlinesEnabled(state.edgeOutlinesEnabled)
		previewBoard.setDieColorPreferences(state.dieColors)
		previewBoard.setD6PipStyle(state.d6PipStyle)
		previewBoard.setFaceNumeralFont(state.faceNumeralFont)

		summaryLabel.translatesAutoresizingMaskIntoConstraints = false
		summaryLabel.font = .systemFont(ofSize: 13, weight: .medium)
		summaryLabel.textColor = palette.secondaryTextColor
		summaryLabel.numberOfLines = 0
		summaryLabel.textAlignment = .center
		summaryLabel.text = summaryText()

		texturePanel.addSubview(previewBoard)
		view.addSubview(texturePanel)
		view.addSubview(summaryLabel)

		NSLayoutConstraint.activate([
			texturePanel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
			texturePanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
			texturePanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
			texturePanel.heightAnchor.constraint(equalTo: texturePanel.widthAnchor, multiplier: 0.64),

			previewBoard.topAnchor.constraint(equalTo: texturePanel.topAnchor),
			previewBoard.leadingAnchor.constraint(equalTo: texturePanel.leadingAnchor),
			previewBoard.trailingAnchor.constraint(equalTo: texturePanel.trailingAnchor),
			previewBoard.bottomAnchor.constraint(equalTo: texturePanel.bottomAnchor),

			summaryLabel.topAnchor.constraint(equalTo: texturePanel.bottomAnchor, constant: 12),
			summaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
			summaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
			summaryLabel.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
		])

		preferredContentSize = CGSize(width: 420, height: 430)
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		let panelBounds = previewBoard.bounds
		guard panelBounds.width > 80, panelBounds.height > 80 else { return }
		let side = max(52, min(96, min(panelBounds.width / 4.2, panelBounds.height / 2.6)))
		let y = panelBounds.midY
		let centers = [
			CGPoint(x: panelBounds.width * 0.20, y: y),
			CGPoint(x: panelBounds.width * 0.40, y: y),
			CGPoint(x: panelBounds.width * 0.60, y: y),
			CGPoint(x: panelBounds.width * 0.80, y: y),
		]
		previewBoard.setDice(
			values: [2, 5, 8, 14],
			centers: centers,
			sideLength: side,
			sideCounts: [4, 6, 10, 20],
			animated: false
		)
	}

	private func summaryText() -> String {
		let texture = NSLocalizedString(state.texture.menuTitleKey, comment: "Texture title")
		let finish = NSLocalizedString(state.dieFinish.menuTitleKey, comment: "Finish title")
		let pip = NSLocalizedString(state.d6PipStyle.menuTitleKey, comment: "Pip style title")
		let font = NSLocalizedString(state.faceNumeralFont.menuTitleKey, comment: "Font title")
		return String(
			format: NSLocalizedString("preview.summary", comment: "Style preview summary text"),
			texture,
			finish,
			pip,
			font
		)
	}

	@objc private func close() {
		dismiss(animated: true)
	}
}

private final class RollHistoryViewController: UITableViewController {
	var onExportText: (() -> Void)?
	var onExportCSV: (() -> Void)?
	var onClearHistory: (() -> Void)?

	private var entries: [RollHistoryEntry]
	private let dateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .none
		formatter.timeStyle = .short
		return formatter
	}()

	init(entries: [RollHistoryEntry]) {
		self.entries = entries
		super.init(style: .insetGrouped)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("history.title", comment: "Roll history title")
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "HistoryCell")
		tableView.accessibilityIdentifier = "historyTable"
		navigationItem.leftBarButtonItem = UIBarButtonItem(
			title: NSLocalizedString("button.close", comment: "Close button title"),
			style: .plain,
			target: self,
			action: #selector(close)
		)
		navigationItem.rightBarButtonItem = UIBarButtonItem(
			title: NSLocalizedString("menu.control.actions", comment: "History actions menu title"),
			menu: historyActionsMenu()
		)
	}

	func updateEntries(_ entries: [RollHistoryEntry]) {
		self.entries = entries
		tableView.reloadData()
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		max(1, entries.count)
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell", for: indexPath)
		if entries.isEmpty {
			cell.textLabel?.text = NSLocalizedString("history.empty", comment: "Empty history message")
			cell.detailTextLabel?.text = nil
			cell.selectionStyle = .none
			return cell
		}
		let entry = entries[indexPath.row]
		var content = UIListContentConfiguration.subtitleCell()
		content.text = "\(entry.notation) = \(entry.sum)"
		content.secondaryText = HistoryRowFormatter.subtitle(for: entry, dateFormatter: dateFormatter)
		cell.contentConfiguration = content
		cell.selectionStyle = .none
		return cell
	}

	private func historyActionsMenu() -> UIMenu {
		let exportText = UIAction(title: NSLocalizedString("history.export.text", comment: "Export history text action")) { [weak self] _ in
			self?.onExportText?()
		}
		let exportCSV = UIAction(title: NSLocalizedString("history.export.csv", comment: "Export history csv action")) { [weak self] _ in
			self?.onExportCSV?()
		}
		let clear = UIAction(
			title: NSLocalizedString("history.clear", comment: "Clear history action"),
			attributes: .destructive
		) { [weak self] _ in
			self?.onClearHistory?()
		}
		return UIMenu(children: [exportText, exportCSV, clear])
	}

	@objc private func close() {
		dismiss(animated: true)
	}
}

extension DiceCollectionViewController: UICollectionViewDelegateFlowLayout {
	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
		layoutSpacing(for: collectionView, mixed: Set(viewModel.diceSideCounts).count > 1)
	}

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
		layoutSpacing(for: collectionView, mixed: Set(viewModel.diceSideCounts).count > 1)
	}

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		let mixed = Set(viewModel.diceSideCounts).count > 1
		let spacing = layoutSpacing(for: collectionView, mixed: mixed)
		let inset = collectionView.adjustedContentInset.left + collectionView.adjustedContentInset.right
		let availableWidth = max(0, collectionView.bounds.width - inset)
		let columns = targetColumnCount(for: availableWidth, mixed: mixed)
		let totalSpacing = CGFloat(columns - 1) * spacing
		let sideLength = floor((availableWidth - totalSpacing) / CGFloat(columns))
		let clamped = max(56, min(160, sideLength))
		return CGSize(width: clamped, height: clamped)
	}

	private func layoutSpacing(for collectionView: UICollectionView, mixed: Bool) -> CGFloat {
		switch viewModel.boardLayoutPreset {
		case .compact:
			return traitCollection.horizontalSizeClass == .regular ? 6 : 3
		case .spacious:
			let regular = mixed ? 14 : 12
			let compact = mixed ? 8 : 6
			return traitCollection.horizontalSizeClass == .regular ? CGFloat(regular) : CGFloat(compact)
		}
	}

	private func targetColumnCount(for availableWidth: CGFloat, mixed: Bool) -> Int {
		if traitCollection.horizontalSizeClass == .regular {
			switch viewModel.boardLayoutPreset {
			case .compact:
				return max(4, min(9, Int(availableWidth / (mixed ? 118 : 110))))
			case .spacious:
				return max(3, min(7, Int(availableWidth / (mixed ? 150 : 138))))
			}
		}
		switch viewModel.boardLayoutPreset {
		case .compact:
			return availableWidth > 460 ? 4 : 3
		case .spacious:
			return availableWidth > 460 ? 3 : 2
		}
	}
}

class DiceCollectionViewCell: UICollectionViewCell {
	private let boardSupportedSides: Set<Int> = [4, 6, 8, 10, 12, 20]
	var onTapDie: (() -> Void)?
	var onToggleLock: (() -> Void)?
	private var currentPalette = DiceTheme.system.palette
	private var isLocked = false
	private var lockGestureConfigured = false

	@IBOutlet weak var diceButton: UIButton!

	override init(frame: CGRect) {
		super.init(frame: frame)
		configureGestures()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		configureGestures()
	}

	override func awakeFromNib() {
		super.awakeFromNib()
		configureGestures()
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		diceButton.frame = contentView.bounds
	}

	func configure(faceValue: Int, sideCount: Int, index: Int, palette: DiceThemePalette, isLocked: Bool) {
		currentPalette = palette
		self.isLocked = isLocked
		diceButton.accessibilityIdentifier = "dieButton_\(index)"
		diceButton.accessibilityLabel = String(
			format: NSLocalizedString("a11y.die.label", comment: "Die button accessibility label format"),
			locale: .current,
			index + 1,
			faceValue
		)
		diceButton.accessibilityHint = isLocked
			? NSLocalizedString("a11y.die.lockedHint", comment: "Locked die accessibility hint")
			: NSLocalizedString("a11y.die.hint", comment: "Die button accessibility hint")
		diceButton.accessibilityTraits = .button
		setFaceValue(faceValue, sideCount: sideCount)
	}

	private func setFaceValue(_ value: Int, sideCount: Int) {
		if boardSupportedSides.contains(sideCount) {
			diceButton.setTitle(nil, for: .normal)
			diceButton.setImage(nil, for: .normal)
			diceButton.layer.borderWidth = isLocked ? 2 : 0
			diceButton.layer.cornerRadius = isLocked ? 8 : 0
			diceButton.layer.borderColor = isLocked ? UIColor.systemYellow.cgColor : UIColor.clear.cgColor
			diceButton.backgroundColor = UIColor.clear
		} else {
			diceButton.setImage(nil, for: .normal)
			diceButton.setTitle("\(value)", for: .normal)
			diceButton.setTitleColor(currentPalette.fallbackDieTextColor, for: .normal)
			diceButton.titleLabel?.font = UIFont.systemFont(ofSize: 36, weight: .bold)
			diceButton.layer.borderColor = isLocked ? UIColor.systemYellow.cgColor : currentPalette.fallbackDieBorderColor.cgColor
			diceButton.layer.borderWidth = isLocked ? 2 : 1
			diceButton.layer.cornerRadius = 8
			diceButton.backgroundColor = currentPalette.fallbackDieBackgroundColor
		}
	}

	private func configureGestures() {
		guard !lockGestureConfigured, let diceButton else { return }
		lockGestureConfigured = true
		let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
		longPress.minimumPressDuration = 0.35
		diceButton.addGestureRecognizer(longPress)
		diceButton.isUserInteractionEnabled = true
	}

	@objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
		if gesture.state == .began {
			onToggleLock?()
		}
	}

	@IBAction func reroll(_ sender: Any) {
		onTapDie?()
	}
}
