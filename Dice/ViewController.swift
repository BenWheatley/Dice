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

private struct HistorySummaryCardRenderer {
	func render(title: String, body: String, footer: String, size: CGSize = CGSize(width: 1080, height: 1080)) -> UIImage {
		let renderer = UIGraphicsImageRenderer(size: size)
		return renderer.image { context in
			let cg = context.cgContext
			UIColor.systemBackground.setFill()
			cg.fill(CGRect(origin: .zero, size: size))

			let panel = CGRect(x: 72, y: 72, width: size.width - 144, height: size.height - 144)
			let panelPath = UIBezierPath(roundedRect: panel, cornerRadius: 36)
			UIColor.secondarySystemBackground.setFill()
			panelPath.fill()

			let titleAttrs: [NSAttributedString.Key: Any] = [
				.font: UIFont.systemFont(ofSize: 58, weight: .bold),
				.foregroundColor: UIColor.label
			]
			let bodyAttrs: [NSAttributedString.Key: Any] = [
				.font: UIFont.monospacedSystemFont(ofSize: 34, weight: .regular),
				.foregroundColor: UIColor.label
			]
			let footerAttrs: [NSAttributedString.Key: Any] = [
				.font: UIFont.systemFont(ofSize: 26, weight: .regular),
				.foregroundColor: UIColor.secondaryLabel
			]
			(title as NSString).draw(in: CGRect(x: panel.minX + 40, y: panel.minY + 44, width: panel.width - 80, height: 80), withAttributes: titleAttrs)
			(body as NSString).draw(in: CGRect(x: panel.minX + 40, y: panel.minY + 140, width: panel.width - 80, height: panel.height - 250), withAttributes: bodyAttrs)
			(footer as NSString).draw(in: CGRect(x: panel.minX + 40, y: panel.maxY - 80, width: panel.width - 80, height: 44), withAttributes: footerAttrs)
		}
	}
}

class DiceCollectionViewController: UICollectionViewController, UITextFieldDelegate {
	private let boardSupportedSides: Set<Int> = [4, 6, 8, 10, 12, 20]
	private let viewModel = DiceViewModel()
	private let soundEngine = DiceSoundEngine()
	private let hapticsEngine = DiceHapticsEngine()

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
		configureAccessibilityRotors()
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
		let anchorPoint = cell.convert(CGPoint(x: cell.bounds.midX, y: cell.bounds.midY), to: view)
		let anchorRect = CGRect(x: anchorPoint.x - 1, y: anchorPoint.y - 1, width: 2, height: 2)
		presentDieOptions(for: indexPath.row, sourceView: view, sourceRect: anchorRect)
	}

	override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! DiceCollectionViewCell
		let faceValue = viewModel.diceValues[indexPath.row]
		let sideCount = viewModel.diceSideCounts[indexPath.row]
		cell.configure(
			faceValue: faceValue,
			sideCount: sideCount,
			index: indexPath.row,
			palette: currentPalette,
			isLocked: viewModel.isDieLocked(at: indexPath.row),
			largeFaceLabelsEnabled: viewModel.largeFaceLabelsEnabled
		)
		cell.onTapDie = { [weak self, weak cell] point in
			guard let self, let cell else { return }
			let anchorPoint = cell.convert(point, to: self.view)
			let anchorRect = CGRect(x: anchorPoint.x - 1, y: anchorPoint.y - 1, width: 2, height: 2)
			self.presentDieOptions(for: indexPath.row, sourceView: self.view, sourceRect: anchorRect)
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
		menuButton.showsMenuAsPrimaryAction = false
		menuButton.addTarget(self, action: #selector(showControlSheet), for: .touchUpInside)

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
		diceBoardView.onRollSettled = { [weak self] in
			self?.playSettleTickSound()
		}
		diceBoardView.setLargeFaceLabelsEnabled(viewModel.largeFaceLabelsEnabled)
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

	private func presentDieOptions(for index: Int, sourceView: UIView, sourceRect: CGRect? = nil) {
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
		let rerollAction = UIAlertAction(title: NSLocalizedString("die.options.reroll", comment: "Reroll one die action"), style: .default) { [weak self] _ in
			self?.rerollDie(at: index)
		}
		rerollAction.isEnabled = !viewModel.isDieLocked(at: index)
		alert.addAction(rerollAction)
		alert.addAction(UIAlertAction(title: NSLocalizedString(lockTitleKey, comment: "Toggle lock action"), style: .default) { [weak self] _ in
			self?.toggleDieLock(at: index)
		})
		alert.addAction(UIAlertAction(title: NSLocalizedString("die.options.color", comment: "Change die color action"), style: .default) { [weak self] _ in
			self?.presentDieColorOptions(forDieAt: index, sideCount: sideCount, sourceView: sourceView, sourceRect: sourceRect)
		})
		if sideCount == 6 {
			alert.addAction(UIAlertAction(title: NSLocalizedString("die.options.pips", comment: "Change d6 pip style action"), style: .default) { [weak self] _ in
				self?.presentD6PipStyleOptions(sourceView: sourceView)
			})
		} else {
			alert.addAction(UIAlertAction(title: NSLocalizedString("die.options.font", comment: "Change numeral font action"), style: .default) { [weak self] _ in
				self?.presentNumeralFontOptions(forDieAt: index, sourceView: sourceView, sourceRect: sourceRect)
			})
		}
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.cancel", comment: "Cancel action"), style: .cancel))
		if let popover = alert.popoverPresentationController {
			popover.sourceView = sourceView
			popover.sourceRect = sourceRect ?? sourceView.bounds
		}
		present(alert, animated: true)
	}

	private func presentDieColorOptions(forDieAt index: Int, sideCount: Int, sourceView: UIView, sourceRect: CGRect?) {
		let alert = UIAlertController(
			title: String(format: NSLocalizedString("die.options.color.title", comment: "Die color sheet title"), sideCount),
			message: nil,
			preferredStyle: .actionSheet
		)
		for preset in DiceDieColorPreset.allCases {
			let isCurrent = (viewModel.dieColorPreset(forDieAt: index) ?? viewModel.dieColorPreset(for: sideCount)) == preset
			let marker = isCurrent ? " ✓" : ""
			let title = NSLocalizedString(preset.menuTitleKey, comment: "Die color option") + marker
			alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
				self?.selectDieColorPreset(preset, sideCount: sideCount, index: index)
			})
		}
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.cancel", comment: "Cancel action"), style: .cancel))
		if let popover = alert.popoverPresentationController {
			popover.sourceView = sourceView
			popover.sourceRect = sourceRect ?? sourceView.bounds
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

	private func presentNumeralFontOptions(forDieAt index: Int, sourceView: UIView, sourceRect: CGRect?) {
		let alert = UIAlertController(
			title: NSLocalizedString("die.options.font.title", comment: "Numeral font sheet title"),
			message: nil,
			preferredStyle: .actionSheet
		)
		for font in DiceFaceNumeralFont.allCases {
			let isCurrent = (viewModel.faceNumeralFont(forDieAt: index) ?? viewModel.faceNumeralFont) == font
			let marker = isCurrent ? " ✓" : ""
			let title = NSLocalizedString(font.menuTitleKey, comment: "Numeral font option") + marker
			alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
				self?.selectFaceNumeralFont(font, dieIndex: index)
			})
		}
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.cancel", comment: "Cancel action"), style: .cancel))
		if let popover = alert.popoverPresentationController {
			popover.sourceView = sourceView
			popover.sourceRect = sourceRect ?? sourceView.bounds
		}
		present(alert, animated: true)
	}

	@discardableResult
	private func rerollDie(at index: Int) -> RollOutcome? {
		guard let outcome = viewModel.rerollDie(at: index) else { return nil }
		updateTotalsText(outcome: outcome)
		collectionView.reloadItems(at: [IndexPath(row: index, section: 0)])
		collectionView.layoutIfNeeded()
		updateDiceBoard(animated: shouldAnimateBoard)
		playRollSound()
		return outcome
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
		diceBoardView.setLargeFaceLabelsEnabled(viewModel.largeFaceLabelsEnabled)
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
			let centerInBoard: CGPoint
			if let cell = collectionView.cellForItem(at: indexPath) {
				centerInBoard = cell.convert(CGPoint(x: cell.bounds.midX, y: cell.bounds.midY), to: diceBoardView)
			} else if let attrs = collectionView.layoutAttributesForItem(at: indexPath) {
				let visibleCenter = CGPoint(
					x: attrs.frame.midX - collectionView.contentOffset.x,
					y: attrs.frame.midY - collectionView.contentOffset.y
				)
				centerInBoard = diceBoardView.convert(visibleCenter, from: collectionView)
			} else {
				continue
			}
			centers.append(centerInBoard)
			values.append(viewModel.diceValues[row])
			boardSideCounts.append(sideCounts[row])
		}

		let colorOverrides = (0..<values.count).map { viewModel.dieColorOverridesByIndex[$0] }
		let fontOverrides = (0..<values.count).map { viewModel.dieFaceNumeralFontOverridesByIndex[$0] }
		diceBoardView.setDice(
			values: values,
			centers: centers,
			sideLength: sideLength,
			sideCounts: boardSideCounts,
			dieColorPresets: colorOverrides,
			faceNumeralFonts: fontOverrides,
			lockedIndices: viewModel.lockedDieIndices,
			animated: animated
		)
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
			guard let dieButton = dieButton(at: index) else { return nil }
			return UIAccessibilityCustomRotorItemResult(targetElement: dieButton, targetRange: nil)
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
			guard let dieButton = dieButton(at: index) else { return nil }
			return UIAccessibilityCustomRotorItemResult(targetElement: dieButton, targetRange: nil)
		}

		view.accessibilityCustomRotors = [rerollRotor, readSidesRotor]
	}

	private func selectedDieIndex(from predicate: UIAccessibilityCustomRotorSearchPredicate) -> Int? {
		if let identifiable = predicate.currentItem.targetElement as? UIAccessibilityIdentification,
		   let currentIdentifier = identifiable.accessibilityIdentifier,
		   let index = Self.dieIndexFromAccessibilityIdentifier(currentIdentifier) {
			return index
		}
		return viewModel.diceValues.isEmpty ? nil : 0
	}

	private func dieButton(at index: Int) -> UIButton? {
		let indexPath = IndexPath(row: index, section: 0)
		guard let cell = collectionView.cellForItem(at: indexPath) as? DiceCollectionViewCell else { return nil }
		return cell.diceButton
	}

	static func dieIndexFromAccessibilityIdentifier(_ identifier: String?) -> Int? {
		guard let identifier else { return nil }
		guard identifier.hasPrefix("dieButton_") else { return nil }
		let suffix = identifier.dropFirst("dieButton_".count)
		return Int(suffix)
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
		}
		historyViewController.onClearPersistedAll = { [weak self, weak historyViewController] in
			guard let self else { return }
			self.viewModel.clearPersistedHistory()
			historyViewController?.updateEntries([], histogramSummary: nil, indicatorSummary: nil, indicatorTooltip: nil)
		}
		historyViewController.onShareSummary = { [weak self] entries in
			self?.shareHistorySummaryCard(entries: entries)
		}
		let navigationController = UINavigationController(rootViewController: historyViewController)
		navigationController.modalPresentationStyle = .formSheet
		if let popover = navigationController.popoverPresentationController {
			popover.sourceView = menuButton
			popover.sourceRect = menuButton.bounds
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
			popover.sourceView = menuButton
			popover.sourceRect = menuButton.bounds
		}
		present(activity, animated: true)
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
		if viewModel.hapticsEnabled {
			hapticsEngine.playInvalidInput()
		}
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
		menuButton.menu = nil
	}

	@objc private func showControlSheet() {
		let sheet = DiceOptionsSheetViewController(
			state: DiceOptionsSheetViewController.State(
				animationsEnabled: viewModel.animationsEnabled,
				animationIntensity: viewModel.animationIntensity,
				showStats: statsVisible,
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
		sheet.onToggleStats = { [weak self] in self?.toggleStatsVisibility() }
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
			popover.sourceView = menuButton
			popover.sourceRect = menuButton.bounds
		}
		present(navigationController, animated: true)
	}

	private func updateLegacyControlMenu() {
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
		let largeLabelsAction = UIAction(
			title: NSLocalizedString("menu.control.largeFaceLabels", comment: "Large face labels toggle title"),
			state: viewModel.largeFaceLabelsEnabled ? .on : .off
		) { [weak self] _ in
			self?.toggleLargeFaceLabels()
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
		let soundEffectsAction = UIAction(
			title: NSLocalizedString("menu.control.soundEffects", comment: "Sound effects toggle title"),
			state: viewModel.soundEffectsEnabled ? .on : .off
		) { [weak self] _ in
			self?.toggleSoundEffects()
		}
		let hapticsAction = UIAction(
			title: NSLocalizedString("menu.control.haptics", comment: "Haptics toggle title"),
			state: viewModel.hapticsEnabled ? .on : .off
		) { [weak self] _ in
			self?.toggleHaptics()
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
		menuButton.menu = UIMenu(children: [historyAction, repeatAction, animationAction, animationIntensityMenu, soundPackMenu, soundEffectsAction, hapticsAction, statsAction, themeMenu, textureMenu, layoutMenu, finishMenu, outlinesAction, motionBlurAction, largeLabelsAction, previewStyleAction, resetVisualsAction])
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

	private func selectDieColorPreset(_ preset: DiceDieColorPreset, sideCount: Int, index: Int) {
		viewModel.setDieColorPreset(preset, forDieAt: index)
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

	private func selectFaceNumeralFont(_ font: DiceFaceNumeralFont, dieIndex: Int? = nil) {
		if let dieIndex {
			viewModel.setFaceNumeralFont(font, forDieAt: dieIndex)
		} else {
			viewModel.setFaceNumeralFont(font)
		}
		diceBoardView.setFaceNumeralFont(font)
		updateDiceBoard(animated: false)
		updateControlMenu()
	}

	private func toggleLargeFaceLabels() {
		viewModel.setLargeFaceLabelsEnabled(!viewModel.largeFaceLabelsEnabled)
		diceBoardView.setLargeFaceLabelsEnabled(viewModel.largeFaceLabelsEnabled)
		collectionView.reloadData()
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

	private func presentStylePreview() {
		let previewState = DiceStylePreviewState(
			theme: viewModel.theme,
			texture: viewModel.tableTexture,
			dieFinish: viewModel.dieFinish,
			edgeOutlinesEnabled: viewModel.edgeOutlinesEnabled,
			dieColors: viewModel.dieColorPreferences,
			d6PipStyle: viewModel.d6PipStyle,
			faceNumeralFont: viewModel.faceNumeralFont,
			largeFaceLabelsEnabled: viewModel.largeFaceLabelsEnabled
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

private final class DiceOptionsSheetViewController: UIViewController {
	struct State {
		let animationsEnabled: Bool
		let animationIntensity: DiceAnimationIntensity
		let showStats: Bool
		let theme: DiceTheme
		let texture: DiceTableTexture
		let layout: DiceBoardLayoutPreset
		let finish: DiceDieFinish
		let edgeOutlinesEnabled: Bool
		let motionBlurEnabled: Bool
		let largeFaceLabelsEnabled: Bool
		let soundPack: DiceSoundPack
		let soundEffectsEnabled: Bool
		let hapticsEnabled: Bool
	}

	var onToggleAnimations: (() -> Void)?
	var onSetAnimationIntensity: ((DiceAnimationIntensity) -> Void)?
	var onToggleStats: (() -> Void)?
	var onSetTheme: ((DiceTheme) -> Void)?
	var onSetTexture: ((DiceTableTexture) -> Void)?
	var onSetLayout: ((DiceBoardLayoutPreset) -> Void)?
	var onSetFinish: ((DiceDieFinish) -> Void)?
	var onToggleEdgeOutlines: (() -> Void)?
	var onToggleMotionBlur: (() -> Void)?
	var onToggleLargeLabels: (() -> Void)?
	var onSetSoundPack: ((DiceSoundPack) -> Void)?
	var onToggleSoundEffects: (() -> Void)?
	var onToggleHaptics: (() -> Void)?
	var onShowHistory: (() -> Void)?
	var onResetVisuals: (() -> Void)?

	private let state: State
	private let scrollView = UIScrollView()
	private let stackView = UIStackView()

	init(state: State) {
		self.state = state
		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("a11y.menu.label", comment: "Main menu accessibility label")
		view.backgroundColor = .systemBackground
		navigationItem.rightBarButtonItem = UIBarButtonItem(
			barButtonSystemItem: .close,
			target: self,
			action: #selector(closeSheet)
		)
		buildForm()
	}

	@objc private func closeSheet() {
		dismiss(animated: true)
	}

	private func buildForm() {
		scrollView.translatesAutoresizingMaskIntoConstraints = false
		stackView.translatesAutoresizingMaskIntoConstraints = false
		stackView.axis = .vertical
		stackView.spacing = 12
		view.addSubview(scrollView)
		scrollView.addSubview(stackView)

		NSLayoutConstraint.activate([
			scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
			scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
			scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
			stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
			stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
			stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
			stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
			stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
		])

		addSection(title: NSLocalizedString("menu.control.animations", comment: "Animations section")) { section in
			section.addSwitchRow(title: NSLocalizedString("menu.control.animations", comment: "Animations toggle menu title"), isOn: state.animationsEnabled) { [weak self] _ in self?.onToggleAnimations?() }
			section.addSegmentRow(
				title: NSLocalizedString("menu.control.animationIntensity", comment: "Animation intensity submenu title"),
				items: DiceAnimationIntensity.allCases.map { NSLocalizedString($0.menuTitleKey, comment: "Animation intensity option") },
				selectedIndex: DiceAnimationIntensity.allCases.firstIndex(of: state.animationIntensity) ?? 0
			) { [weak self] index in
				guard DiceAnimationIntensity.allCases.indices.contains(index) else { return }
				self?.onSetAnimationIntensity?(DiceAnimationIntensity.allCases[index])
			}
			section.addSwitchRow(title: NSLocalizedString("menu.control.showStats", comment: "Show stats toggle menu title"), isOn: state.showStats) { [weak self] _ in self?.onToggleStats?() }
		}
		addSection(title: NSLocalizedString("menu.control.theme", comment: "Visual section")) { section in
			section.addSegmentRow(title: NSLocalizedString("menu.control.theme", comment: "Theme submenu title"), items: DiceTheme.allCases.map { NSLocalizedString($0.menuTitleKey, comment: "Theme option title") }, selectedIndex: DiceTheme.allCases.firstIndex(of: state.theme) ?? 0) { [weak self] index in
				guard DiceTheme.allCases.indices.contains(index) else { return }
				self?.onSetTheme?(DiceTheme.allCases[index])
			}
			section.addSegmentRow(title: NSLocalizedString("menu.control.texture", comment: "Texture submenu title"), items: DiceTableTexture.allCases.map { NSLocalizedString($0.menuTitleKey, comment: "Table texture option") }, selectedIndex: DiceTableTexture.allCases.firstIndex(of: state.texture) ?? 0) { [weak self] index in
				guard DiceTableTexture.allCases.indices.contains(index) else { return }
				self?.onSetTexture?(DiceTableTexture.allCases[index])
			}
			section.addSegmentRow(title: NSLocalizedString("menu.control.layout", comment: "Layout submenu title"), items: DiceBoardLayoutPreset.allCases.map { NSLocalizedString($0.menuTitleKey, comment: "Board layout option") }, selectedIndex: DiceBoardLayoutPreset.allCases.firstIndex(of: state.layout) ?? 0) { [weak self] index in
				guard DiceBoardLayoutPreset.allCases.indices.contains(index) else { return }
				self?.onSetLayout?(DiceBoardLayoutPreset.allCases[index])
			}
			section.addSegmentRow(title: NSLocalizedString("menu.control.finish", comment: "Finish submenu title"), items: DiceDieFinish.allCases.map { NSLocalizedString($0.menuTitleKey, comment: "Die finish option") }, selectedIndex: DiceDieFinish.allCases.firstIndex(of: state.finish) ?? 0) { [weak self] index in
				guard DiceDieFinish.allCases.indices.contains(index) else { return }
				self?.onSetFinish?(DiceDieFinish.allCases[index])
			}
			section.addSwitchRow(title: NSLocalizedString("menu.control.edgeOutlines", comment: "Edge outlines toggle menu title"), isOn: state.edgeOutlinesEnabled) { [weak self] _ in self?.onToggleEdgeOutlines?() }
			section.addSwitchRow(title: NSLocalizedString("menu.control.motionBlur", comment: "Motion blur toggle menu title"), isOn: state.motionBlurEnabled) { [weak self] _ in self?.onToggleMotionBlur?() }
			section.addSwitchRow(title: NSLocalizedString("menu.control.largeFaceLabels", comment: "Large face labels toggle title"), isOn: state.largeFaceLabelsEnabled) { [weak self] _ in self?.onToggleLargeLabels?() }
		}
		addSection(title: NSLocalizedString("menu.control.soundPack", comment: "Sound section")) { section in
			section.addSegmentRow(title: NSLocalizedString("menu.control.soundPack", comment: "Sound pack submenu title"), items: DiceSoundPack.allCases.map { NSLocalizedString($0.menuTitleKey, comment: "Sound pack option") }, selectedIndex: DiceSoundPack.allCases.firstIndex(of: state.soundPack) ?? 0) { [weak self] index in
				guard DiceSoundPack.allCases.indices.contains(index) else { return }
				self?.onSetSoundPack?(DiceSoundPack.allCases[index])
			}
			section.addSwitchRow(title: NSLocalizedString("menu.control.soundEffects", comment: "Sound effects toggle title"), isOn: state.soundEffectsEnabled) { [weak self] _ in self?.onToggleSoundEffects?() }
			section.addSwitchRow(title: NSLocalizedString("menu.control.haptics", comment: "Haptics toggle title"), isOn: state.hapticsEnabled) { [weak self] _ in self?.onToggleHaptics?() }
		}
		addSection(title: NSLocalizedString("menu.control.actions", comment: "Actions section")) { section in
			section.addActionButton(title: NSLocalizedString("button.history", comment: "History button title")) { [weak self] in self?.onShowHistory?() }
			section.addActionButton(title: NSLocalizedString("menu.control.resetVisuals", comment: "Reset visual settings menu title"), destructive: true) { [weak self] in self?.onResetVisuals?() }
		}
	}

	private func addSection(title: String, build: (DiceOptionsSectionBuilder) -> Void) {
		let sectionStack = UIStackView()
		sectionStack.axis = .vertical
		sectionStack.spacing = 8
		let header = UILabel()
		header.text = title
		header.font = .preferredFont(forTextStyle: .headline)
		sectionStack.addArrangedSubview(header)
		let body = UIStackView()
		body.axis = .vertical
		body.spacing = 10
		body.isLayoutMarginsRelativeArrangement = true
		body.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
		body.backgroundColor = .secondarySystemGroupedBackground
		body.layer.cornerRadius = 12
		sectionStack.addArrangedSubview(body)
		build(DiceOptionsSectionBuilder(stackView: body))
		stackView.addArrangedSubview(sectionStack)
	}
}

private struct DiceOptionsSectionBuilder {
	let stackView: UIStackView

	func addSwitchRow(title: String, isOn: Bool, action: @escaping (Bool) -> Void) {
		let row = UIStackView()
		row.axis = .horizontal
		row.alignment = .center
		row.spacing = 12
		let label = UILabel()
		label.text = title
		label.numberOfLines = 0
		let toggle = UISwitch()
		toggle.isOn = isOn
		toggle.accessibilityLabel = title
		toggle.addAction(UIAction { _ in action(toggle.isOn) }, for: .valueChanged)
		row.addArrangedSubview(label)
		row.addArrangedSubview(toggle)
		stackView.addArrangedSubview(row)
	}

	func addSegmentRow(title: String, items: [String], selectedIndex: Int, action: @escaping (Int) -> Void) {
		let container = UIStackView()
		container.axis = .vertical
		container.spacing = 8
		let label = UILabel()
		label.text = title
		let segmented = UISegmentedControl(items: items)
		segmented.selectedSegmentIndex = selectedIndex
		segmented.addAction(UIAction { _ in action(segmented.selectedSegmentIndex) }, for: .valueChanged)
		container.addArrangedSubview(label)
		container.addArrangedSubview(segmented)
		stackView.addArrangedSubview(container)
	}

	func addActionButton(title: String, destructive: Bool = false, action: @escaping () -> Void) {
		let button = UIButton(type: .system)
		button.setTitle(title, for: .normal)
		button.contentHorizontalAlignment = .leading
		if destructive {
			button.setTitleColor(.systemRed, for: .normal)
		}
		button.addAction(UIAction { _ in action() }, for: .touchUpInside)
		stackView.addArrangedSubview(button)
	}
}

private final class DiceSoundEngine {
	private let engine = AVAudioEngine()
	private let player = AVAudioPlayerNode()
	private let audioQueue = DispatchQueue(label: "com.kitsunesoftware.dice.soundengine")
	private var cachedImpactBuffers: [DiceSoundPack: AVAudioPCMBuffer] = [:]
	private var cachedTickBuffers: [DiceSoundPack: AVAudioPCMBuffer] = [:]
	private var currentPack: DiceSoundPack = .off
	private var isEnabled = true
	private var didStartEngine = false

	init() {
		engine.attach(player)
		engine.connect(player, to: engine.mainMixerNode, format: nil)
	}

	func configure(pack: DiceSoundPack, enabled: Bool) {
		audioQueue.async { [weak self] in
			self?.currentPack = pack
			self?.isEnabled = enabled
		}
	}

	func playRollImpact() {
		audioQueue.async { [weak self] in
			guard let self else { return }
			guard self.isEnabled else { return }
			guard self.currentPack != .off else { return }
			self.ensureEngineStarted()
			guard let baseBuffer = self.impactBuffer(for: self.currentPack),
				  let buffer = self.copyBuffer(baseBuffer) else { return }
			self.player.volume = 1.0
			self.player.scheduleBuffer(buffer, at: nil, options: []) { }
			if !self.player.isPlaying {
				self.player.play()
			}
		}
	}

	func playSettleTick() {
		audioQueue.async { [weak self] in
			guard let self else { return }
			guard self.isEnabled else { return }
			guard self.currentPack != .off else { return }
			self.ensureEngineStarted()
			guard let baseBuffer = self.tickBuffer(for: self.currentPack),
				  let buffer = self.copyBuffer(baseBuffer) else { return }
			self.player.volume = 0.9
			self.player.scheduleBuffer(buffer, at: nil, options: []) { }
			if !self.player.isPlaying {
				self.player.play()
			}
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

	private func impactBuffer(for pack: DiceSoundPack) -> AVAudioPCMBuffer? {
		if let cached = cachedImpactBuffers[pack] {
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
		cachedImpactBuffers[pack] = buffer
		return buffer
	}

	private func tickBuffer(for pack: DiceSoundPack) -> AVAudioPCMBuffer? {
		if let cached = cachedTickBuffers[pack] {
			return cached
		}
		guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else {
			return nil
		}
		let frameCount: AVAudioFrameCount = 1_800
		guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
			return nil
		}
		buffer.frameLength = frameCount
		guard let channel = buffer.floatChannelData?.pointee else {
			return nil
		}
		fillTick(channel: channel, count: Int(frameCount), sampleRate: Float(format.sampleRate), pack: pack)
		cachedTickBuffers[pack] = buffer
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

	private func fillTick(channel: UnsafeMutablePointer<Float>, count: Int, sampleRate: Float, pack: DiceSoundPack) {
		let twoPi = Float.pi * 2
		for index in 0..<count {
			let t = Float(index) / sampleRate
			let envelope = exp(-34 * t)
			let noise = Float.random(in: -1...1)
			let toneFrequency: Float = pack == .softWood ? 1_280 : 1_880
			let tone = sin(twoPi * toneFrequency * t)
			let mix: Float = pack == .softWood ? ((0.6 * noise) + (0.4 * tone)) : ((0.82 * noise) + (0.18 * tone))
			channel[index] = max(-1, min(1, mix * envelope * 0.75))
		}
	}

	private func copyBuffer(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
		guard let copy = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: source.frameLength) else {
			return nil
		}
		copy.frameLength = source.frameLength
		guard let fromChannels = source.floatChannelData, let toChannels = copy.floatChannelData else {
			return nil
		}
		let channels = Int(source.format.channelCount)
		let frames = Int(source.frameLength)
		for channel in 0..<channels {
			toChannels[channel].assign(from: fromChannels[channel], count: frames)
		}
		return copy
	}
}

private final class DiceHapticsEngine {
	private let impact = UIImpactFeedbackGenerator(style: .medium)
	private let settle = UIImpactFeedbackGenerator(style: .soft)
	private let invalid = UINotificationFeedbackGenerator()

	func playRollImpact() {
		impact.prepare()
		impact.impactOccurred(intensity: 0.85)
	}

	func playRollSettle() {
		settle.prepare()
		settle.impactOccurred(intensity: 0.65)
	}

	func playInvalidInput() {
		invalid.notificationOccurred(.warning)
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
	let largeFaceLabelsEnabled: Bool
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
		previewBoard.setLargeFaceLabelsEnabled(state.largeFaceLabelsEnabled)

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

private final class RollHistoryViewController: UITableViewController, UISearchResultsUpdating {
	var onExportText: (() -> Void)?
	var onExportCSV: (() -> Void)?
	var onClearRecentOnly: (() -> Void)?
	var onClearPersistedAll: (() -> Void)?
	var onShareSummary: (([RollHistoryEntry]) -> Void)?

	private var allEntries: [RollHistoryEntry]
	private var visibleEntries: [RollHistoryEntry]
	private var histogramSummary: String?
	private var indicatorSummary: String?
	private var indicatorTooltip: String?
	private var activeFilter: RollHistoryFilter = .default
	private let dateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .none
		formatter.timeStyle = .short
		return formatter
	}()

	init(entries: [RollHistoryEntry], histogramSummary: String?, indicatorSummary: String?, indicatorTooltip: String?) {
		self.allEntries = entries
		self.visibleEntries = entries
		self.histogramSummary = histogramSummary
		self.indicatorSummary = indicatorSummary
		self.indicatorTooltip = indicatorTooltip
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
		let actionsButton = UIBarButtonItem(
			title: NSLocalizedString("menu.control.actions", comment: "History actions menu title"),
			menu: historyActionsMenu()
		)
		let filterButton = UIBarButtonItem(
			image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
			menu: filterMenu()
		)
		filterButton.accessibilityIdentifier = "historyFilterButton"
		navigationItem.rightBarButtonItems = [actionsButton, filterButton]
		let searchController = UISearchController(searchResultsController: nil)
		searchController.obscuresBackgroundDuringPresentation = false
		searchController.searchBar.placeholder = NSLocalizedString("history.search.placeholder", comment: "History search placeholder")
		searchController.searchResultsUpdater = self
		navigationItem.searchController = searchController
		navigationItem.hidesSearchBarWhenScrolling = false
		definesPresentationContext = true
		updateIndicatorHelpButton()
		updateHistogramHeader()
	}

	func updateEntries(_ entries: [RollHistoryEntry], histogramSummary: String?, indicatorSummary: String?, indicatorTooltip: String?) {
		self.allEntries = entries
		self.histogramSummary = histogramSummary
		self.indicatorSummary = indicatorSummary
		self.indicatorTooltip = indicatorTooltip
		applyFilters()
		updateIndicatorHelpButton()
		updateHistogramHeader()
		tableView.reloadData()
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		max(1, visibleEntries.count)
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell", for: indexPath)
		if visibleEntries.isEmpty {
			cell.textLabel?.text = NSLocalizedString("history.empty", comment: "Empty history message")
			cell.detailTextLabel?.text = nil
			cell.selectionStyle = .none
			return cell
		}
		let entry = visibleEntries[indexPath.row]
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
		let shareSummary = UIAction(title: NSLocalizedString("history.export.summary", comment: "Share summary card action")) { [weak self] _ in
			guard let self else { return }
			onShareSummary?(visibleEntries)
		}
		let clearRecent = UIAction(
			title: NSLocalizedString("history.clearRecent", comment: "Clear recent history action"),
			attributes: .destructive
		) { [weak self] _ in
			self?.onClearRecentOnly?()
		}
		let clearPersisted = UIAction(
			title: NSLocalizedString("history.clearPersisted", comment: "Clear persisted history action"),
			attributes: .destructive
		) { [weak self] _ in
			self?.onClearPersistedAll?()
		}
		return UIMenu(children: [exportText, exportCSV, shareSummary, clearRecent, clearPersisted])
	}

	private func filterMenu() -> UIMenu {
		let modeActions: [UIAction] = [
			UIAction(
				title: NSLocalizedString("history.filter.mode.all", comment: "History mode all filter"),
				state: activeFilter.mode == .all ? .on : .off
			) { [weak self] _ in self?.setModeFilter(.all) },
			UIAction(
				title: NSLocalizedString("history.filter.mode.trueRandom", comment: "History true random mode filter"),
				state: activeFilter.mode == .trueRandom ? .on : .off
			) { [weak self] _ in self?.setModeFilter(.trueRandom) },
			UIAction(
				title: NSLocalizedString("history.filter.mode.intuitive", comment: "History intuitive mode filter"),
				state: activeFilter.mode == .intuitive ? .on : .off
			) { [weak self] _ in self?.setModeFilter(.intuitive) },
		]
		let rangeActions: [UIAction] = [
			UIAction(
				title: NSLocalizedString("history.filter.range.all", comment: "History date range all"),
				state: activeFilter.dateRange == .all ? .on : .off
			) { [weak self] _ in self?.setDateRangeFilter(.all) },
			UIAction(
				title: NSLocalizedString("history.filter.range.24h", comment: "History date range 24h"),
				state: activeFilter.dateRange == .last24Hours ? .on : .off
			) { [weak self] _ in self?.setDateRangeFilter(.last24Hours) },
			UIAction(
				title: NSLocalizedString("history.filter.range.7d", comment: "History date range 7d"),
				state: activeFilter.dateRange == .last7Days ? .on : .off
			) { [weak self] _ in self?.setDateRangeFilter(.last7Days) },
			UIAction(
				title: NSLocalizedString("history.filter.range.30d", comment: "History date range 30d"),
				state: activeFilter.dateRange == .last30Days ? .on : .off
			) { [weak self] _ in self?.setDateRangeFilter(.last30Days) },
		]
		let resetAction = UIAction(title: NSLocalizedString("history.filter.reset", comment: "Reset history filters")) { [weak self] _ in
			self?.resetFilters()
		}
		let modeMenu = UIMenu(
			title: NSLocalizedString("history.filter.mode.title", comment: "History mode filter menu title"),
			options: .displayInline,
			children: modeActions
		)
		let rangeMenu = UIMenu(
			title: NSLocalizedString("history.filter.range.title", comment: "History date range filter menu title"),
			options: .displayInline,
			children: rangeActions
		)
		return UIMenu(children: [modeMenu, rangeMenu, resetAction])
	}

	private func setModeFilter(_ mode: RollHistoryModeFilter) {
		activeFilter.mode = mode
		applyFilters()
		refreshFilterButtonMenu()
	}

	private func setDateRangeFilter(_ range: RollHistoryDateRangeFilter) {
		activeFilter.dateRange = range
		applyFilters()
		refreshFilterButtonMenu()
	}

	private func resetFilters() {
		activeFilter = .default
		navigationItem.searchController?.searchBar.text = nil
		applyFilters()
		refreshFilterButtonMenu()
	}

	private func refreshFilterButtonMenu() {
		let actionsButton = navigationItem.rightBarButtonItems?.first
		let filterButton = UIBarButtonItem(
			image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
			menu: filterMenu()
		)
		filterButton.accessibilityIdentifier = "historyFilterButton"
		if let actionsButton {
			navigationItem.rightBarButtonItems = [actionsButton, filterButton]
		} else {
			navigationItem.rightBarButtonItems = [filterButton]
		}
	}

	private func applyFilters() {
		visibleEntries = RollHistoryAnalytics.filteredEntries(entries: allEntries, filter: activeFilter)
		tableView.reloadData()
	}

	func updateSearchResults(for searchController: UISearchController) {
		activeFilter.searchText = searchController.searchBar.text ?? ""
		applyFilters()
	}

	private func updateHistogramHeader() {
		let combinedText = [histogramSummary, indicatorSummary]
			.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
			.joined(separator: "\n\n")
		guard !combinedText.isEmpty else {
			tableView.tableHeaderView = nil
			return
		}
		let container = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 0))
		let label = UILabel()
		label.translatesAutoresizingMaskIntoConstraints = false
		label.numberOfLines = 0
		label.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
		label.textColor = .secondaryLabel
		label.text = combinedText
		container.addSubview(label)
		NSLayoutConstraint.activate([
			label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
			label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
			label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
			label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
		])
		let targetWidth = tableView.bounds.width > 0 ? tableView.bounds.width : 420
		let size = container.systemLayoutSizeFitting(
			CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height),
			withHorizontalFittingPriority: .required,
			verticalFittingPriority: .fittingSizeLevel
		)
		container.frame = CGRect(x: 0, y: 0, width: targetWidth, height: size.height)
		tableView.tableHeaderView = container
	}

	private func updateIndicatorHelpButton() {
		guard let indicatorTooltip, !indicatorTooltip.isEmpty else {
			navigationItem.leftBarButtonItems = [UIBarButtonItem(
				title: NSLocalizedString("button.close", comment: "Close button title"),
				style: .plain,
				target: self,
				action: #selector(close)
			)]
			return
		}
		let close = UIBarButtonItem(
			title: NSLocalizedString("button.close", comment: "Close button title"),
			style: .plain,
			target: self,
			action: #selector(close)
		)
		let help = UIBarButtonItem(
			image: UIImage(systemName: "info.circle"),
			style: .plain,
			target: self,
			action: #selector(showIndicatorsHelp)
		)
		help.accessibilityIdentifier = "historyIndicatorsHelpButton"
		navigationItem.leftBarButtonItems = [close, help]
	}

	@objc private func showIndicatorsHelp() {
		guard let indicatorTooltip, !indicatorTooltip.isEmpty else { return }
		let alert = UIAlertController(
			title: NSLocalizedString("history.indicators.title", comment: "History indicator help title"),
			message: indicatorTooltip,
			preferredStyle: .alert
		)
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.ok", comment: "Generic confirmation button"), style: .default))
		present(alert, animated: true)
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
	var onTapDie: ((CGPoint) -> Void)?
	var onToggleLock: (() -> Void)?
	private var currentPalette = DiceTheme.system.palette
	private var isLocked = false
	private var lockGestureConfigured = false
	private let lockIconView = UIImageView(image: UIImage(systemName: "lock.fill"))

	@IBOutlet weak var diceButton: UIButton!

	override init(frame: CGRect) {
		super.init(frame: frame)
		configureGestures()
		configureLockIcon()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		configureGestures()
		configureLockIcon()
	}

	override func awakeFromNib() {
		super.awakeFromNib()
		configureGestures()
		configureLockIcon()
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		diceButton.frame = contentView.bounds
		let iconSize: CGFloat = 18
		lockIconView.frame = CGRect(x: contentView.bounds.maxX - iconSize - 4, y: 4, width: iconSize, height: iconSize)
	}

	func configure(faceValue: Int, sideCount: Int, index: Int, palette: DiceThemePalette, isLocked: Bool, largeFaceLabelsEnabled: Bool) {
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
		setFaceValue(faceValue, sideCount: sideCount, largeFaceLabelsEnabled: largeFaceLabelsEnabled)
		lockIconView.isHidden = !isLocked
	}

	private func setFaceValue(_ value: Int, sideCount: Int, largeFaceLabelsEnabled: Bool) {
		if boardSupportedSides.contains(sideCount) {
			diceButton.setTitle(nil, for: .normal)
			diceButton.setImage(nil, for: .normal)
			diceButton.layer.borderWidth = 0
			diceButton.layer.cornerRadius = 0
			diceButton.layer.borderColor = UIColor.clear.cgColor
			diceButton.backgroundColor = UIColor.clear
		} else {
			diceButton.setImage(nil, for: .normal)
			diceButton.setTitle("\(value)", for: .normal)
			diceButton.setTitleColor(currentPalette.fallbackDieTextColor, for: .normal)
			let side = min(contentView.bounds.width, contentView.bounds.height)
			let pointSize = DiceFaceLabelSizing.staticFallbackPointSize(cellSideLength: side, large: largeFaceLabelsEnabled)
			diceButton.titleLabel?.font = UIFont.systemFont(ofSize: pointSize, weight: .bold)
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

	private func configureLockIcon() {
		guard lockIconView.superview == nil else { return }
		lockIconView.tintColor = .systemYellow
		lockIconView.contentMode = .scaleAspectFit
		lockIconView.layer.shadowColor = UIColor.black.cgColor
		lockIconView.layer.shadowOpacity = 0.35
		lockIconView.layer.shadowRadius = 1.5
		lockIconView.layer.shadowOffset = CGSize(width: 0, height: 1)
		lockIconView.isHidden = true
		contentView.addSubview(lockIconView)
		contentView.bringSubviewToFront(lockIconView)
	}

	@objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
		if gesture.state == .began {
			onToggleLock?()
		}
	}

	@IBAction func reroll(_ sender: Any) {
		guard let button = sender as? UIButton else {
			onTapDie?(CGPoint(x: contentView.bounds.midX, y: contentView.bounds.midY))
			return
		}
		let point = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: contentView)
		onTapDie?(point)
	}
}
