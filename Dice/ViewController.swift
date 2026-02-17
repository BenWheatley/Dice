//
//  ViewController.swift
//  Dice
//
//  Created by Ben Wheatley on 2018/09/27.
//  Copyright © 2018 Ben Wheatley. All rights reserved.
//

import UIKit

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

	private let notationField = UITextField()
	private let validationLabel = UILabel()
	private let totalsLabel = UILabel()
	private let totalsContainer = UIView()
	private let rollButton = UIButton(type: .system)
	private let presetsButton = UIButton(type: .system)
	private let menuButton = UIButton(type: .system)
	private let diceBoardView = DiceCubeView()
	private var controlsContainer: UIView?
	private var currentPalette = DiceTheme.classic.palette
	private var currentTexture: DiceTableTexture = .neutral
	private var currentDieFinish: DiceDieFinish = .matte
	private let customizableSideCounts = DiceDieColorPreferences.supportedSideCounts
	private let statsVisibilityKey = "Dice.showStats"
	private var statsVisible = true

	override func viewDidLoad() {
		super.viewDidLoad()
		viewModel.restore()

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

	override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! DiceCollectionViewCell
		let faceValue = viewModel.diceValues[indexPath.row]
		let sideCount = viewModel.diceSideCounts[indexPath.row]
		cell.configure(faceValue: faceValue, sideCount: sideCount, index: indexPath.row, palette: currentPalette)
		cell.onRequestReroll = { [weak self, weak collectionView] in
			guard let self else { return }
			guard let outcome = self.viewModel.rerollDie(at: indexPath.row) else { return }
			self.updateTotalsText(outcome: outcome)
			collectionView?.reloadItems(at: [indexPath])
			collectionView?.layoutIfNeeded()
			self.updateDiceBoard(animated: self.shouldAnimateBoard)
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
		case let .failure(error):
			showValidationError(message: error.userMessage)
		}
	}

	private func performRoll() {
		let outcome = viewModel.rollCurrent()
		updateNotationField()
		updateTotalsText(outcome: outcome)
		collectionView.collectionViewLayout.invalidateLayout()
		collectionView.reloadData()
		collectionView.layoutIfNeeded()
		updateDiceBoard(animated: shouldAnimateBoard)
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

		let sideLength = 0.25 * min(collectionView.bounds.width, collectionView.bounds.height)
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
		clearValidationFeedback()
	}

	@objc private func focusNotationField() {
		notationField.becomeFirstResponder()
	}

	@objc private func toggleAnimations() {
		viewModel.setAnimationsEnabled(!viewModel.animationsEnabled)
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
		let toolbar = UIToolbar()
		toolbar.sizeToFit()
		toolbar.items = [
			UIBarButtonItem(title: NSLocalizedString("toolbar.roll", comment: "Notation keyboard accessory roll action"), style: .done, target: self, action: #selector(rollFromInput)),
			UIBarButtonItem.flexibleSpace(),
			UIBarButtonItem(barButtonSystemItem: .done, target: notationField, action: #selector(UIResponder.resignFirstResponder)),
		]
		notationField.inputAccessoryView = toolbar
	}

	private func configurePointerInteractionsIfNeeded() {
		guard traitCollection.userInterfaceIdiom == .mac else { return }
		for control in [rollButton, presetsButton, menuButton] {
			control.isPointerInteractionEnabled = true
		}
	}

	private var shouldAnimateBoard: Bool {
		let sideCounts = viewModel.diceSideCounts
		return !sideCounts.isEmpty && sideCounts.allSatisfy({ boardSupportedSides.contains($0) }) && viewModel.animationsEnabled
	}

	@objc private func showPresetPicker() {
		let picker = PresetPickerViewController()
		picker.onSelectPreset = { [weak self] diceCount, intuitive in
			self?.applyPreset(diceCount: diceCount, intuitive: intuitive)
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
		let statsAction = UIAction(
			title: NSLocalizedString("menu.control.showStats", comment: "Show stats toggle menu title"),
			state: statsVisible ? .on : .off
		) { [weak self] _ in
			self?.toggleStatsVisibility()
		}
		let historyAction = UIAction(title: NSLocalizedString("button.history", comment: "History button title")) { [weak self] _ in
			self?.showHistory()
		}
		let themeActions = DiceTheme.allCases.map { theme in
			UIAction(
				title: self.themeTitle(for: theme),
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
		let pipStyleActions = DiceD6PipStyle.allCases.map { style in
			UIAction(
				title: NSLocalizedString(style.menuTitleKey, comment: "D6 pip style option"),
				state: viewModel.d6PipStyle == style ? .on : .off
			) { [weak self] _ in
				self?.selectD6PipStyle(style)
			}
		}
		let pipStyleMenu = UIMenu(
			title: NSLocalizedString("menu.control.pipStyle", comment: "D6 pip style submenu title"),
			options: .displayInline,
			children: pipStyleActions
		)
		let dieColorMenus = customizableSideCounts.map { sideCount in
			let actions = DiceDieColorPreset.allCases.map { preset in
				UIAction(
					title: NSLocalizedString(preset.menuTitleKey, comment: "Die color preset option"),
					state: viewModel.dieColorPreset(for: sideCount) == preset ? .on : .off
				) { [weak self] _ in
					self?.selectDieColorPreset(preset, sideCount: sideCount)
				}
			}
			return UIMenu(
				title: String(format: NSLocalizedString("menu.control.dieColor.side", comment: "Die color submenu title for side count"), sideCount),
				options: .displayInline,
				children: actions
			)
		}
		let dieColorsMenu = UIMenu(
			title: NSLocalizedString("menu.control.dieColors", comment: "Die colors submenu title"),
			options: .displayInline,
			children: dieColorMenus
		)
		let outlinesAction = UIAction(
			title: NSLocalizedString("menu.control.edgeOutlines", comment: "Edge outlines toggle menu title"),
			state: viewModel.edgeOutlinesEnabled ? .on : .off
		) { [weak self] _ in
			self?.toggleEdgeOutlines()
		}
		let resetAction = UIAction(title: NSLocalizedString("button.reset", comment: "Reset button title"), attributes: .destructive) { [weak self] _ in
			self?.resetStats()
		}
		menuButton.menu = UIMenu(children: [historyAction, themeMenu, textureMenu, finishMenu, pipStyleMenu, dieColorsMenu, outlinesAction, animationAction, statsAction, resetAction])
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

	private func applyTheme() {
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
		notationField.keyboardAppearance = viewModel.theme == .classic ? .default : .dark
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

	private func themeTitle(for theme: DiceTheme) -> String {
		switch theme {
		case .classic:
			return NSLocalizedString("theme.classic", comment: "Classic theme title")
		case .darkSlate:
			return NSLocalizedString("theme.darkSlate", comment: "Dark slate theme title")
		case .highContrast:
			return NSLocalizedString("theme.highContrast", comment: "High contrast theme title")
		}
	}
}

private final class PresetPickerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
	var onSelectPreset: ((Int, Bool) -> Void)?

	private let normalTableView = UITableView(frame: .zero, style: .insetGrouped)
	private let intuitiveTableView = UITableView(frame: .zero, style: .insetGrouped)

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
		layoutSpacing(for: collectionView)
	}

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
		layoutSpacing(for: collectionView)
	}

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		let spacing = layoutSpacing(for: collectionView)
		let inset = collectionView.adjustedContentInset.left + collectionView.adjustedContentInset.right
		let availableWidth = max(0, collectionView.bounds.width - inset)
		let columns = targetColumnCount(for: availableWidth)
		let totalSpacing = CGFloat(columns - 1) * spacing
		let sideLength = floor((availableWidth - totalSpacing) / CGFloat(columns))
		let clamped = max(56, min(160, sideLength))
		return CGSize(width: clamped, height: clamped)
	}

	private func layoutSpacing(for collectionView: UICollectionView) -> CGFloat {
		traitCollection.horizontalSizeClass == .regular ? 8 : 4
	}

	private func targetColumnCount(for availableWidth: CGFloat) -> Int {
		if traitCollection.horizontalSizeClass == .regular {
			return max(4, min(8, Int(availableWidth / 120)))
		}
		return availableWidth > 460 ? 4 : 3
	}
}

class DiceCollectionViewCell: UICollectionViewCell {
	private let boardSupportedSides: Set<Int> = [4, 6, 8, 10, 12, 20]
	var onRequestReroll: (() -> Void)?
	private var currentPalette = DiceTheme.classic.palette

	@IBOutlet weak var diceButton: UIButton!

	override func layoutSubviews() {
		super.layoutSubviews()
		diceButton.frame = contentView.bounds
	}

	func configure(faceValue: Int, sideCount: Int, index: Int, palette: DiceThemePalette) {
		currentPalette = palette
		diceButton.accessibilityIdentifier = "dieButton_\(index)"
		diceButton.accessibilityLabel = String(
			format: NSLocalizedString("a11y.die.label", comment: "Die button accessibility label format"),
			locale: .current,
			index + 1,
			faceValue
		)
		diceButton.accessibilityHint = NSLocalizedString("a11y.die.hint", comment: "Die button accessibility hint")
		diceButton.accessibilityTraits = .button
		setFaceValue(faceValue, sideCount: sideCount)
	}

	private func setFaceValue(_ value: Int, sideCount: Int) {
		if boardSupportedSides.contains(sideCount) {
			diceButton.setTitle(nil, for: .normal)
			diceButton.setImage(nil, for: .normal)
			diceButton.layer.borderWidth = 0
			diceButton.layer.cornerRadius = 0
			diceButton.backgroundColor = UIColor.clear
		} else {
			diceButton.setImage(nil, for: .normal)
			diceButton.setTitle("\(value)", for: .normal)
			diceButton.setTitleColor(currentPalette.fallbackDieTextColor, for: .normal)
			diceButton.titleLabel?.font = UIFont.systemFont(ofSize: 36, weight: .bold)
			diceButton.layer.borderColor = currentPalette.fallbackDieBorderColor.cgColor
			diceButton.layer.borderWidth = 1
			diceButton.layer.cornerRadius = 8
			diceButton.backgroundColor = currentPalette.fallbackDieBackgroundColor
		}
	}

	@IBAction func reroll(_ sender: Any) {
		onRequestReroll?()
	}
}
