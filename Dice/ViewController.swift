//
//  ViewController.swift
//  Dice
//
//  Created by Ben Wheatley on 2018/09/27.
//  Copyright © 2018 Ben Wheatley. All rights reserved.
//

import UIKit

private let reuseIdentifier = "DiceCell"

class DiceCollectionViewController: UICollectionViewController, UITextFieldDelegate {
	private let boardSupportedSides: Set<Int> = [4, 6, 8, 10, 12, 20]
	private let viewModel = DiceViewModel()

	private let notationField = UITextField()
	private let validationLabel = UILabel()
	private let totalsLabel = UILabel()
	private let totalsContainer = UIView()
	private let resetStatsButton = UIButton(type: .system)
	private let presetsButton = UIButton(type: .system)
	private let historyButton = UIButton(type: .system)
	private let animationButton = UIButton(type: .system)
	private let diceBoardView = DiceCubeView()
	private var controlsContainer: UIView?

	override func viewDidLoad() {
		super.viewDidLoad()
		viewModel.restore()

		collectionView.backgroundColor = UIColor(patternImage: UIImage(named: "stripes")!)
		collectionView.keyboardDismissMode = .onDrag
		configureControls()
		configureDiceBoard()
		updateNotationField()
		updateAnimationButtonState()
		performRoll()
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		guard let controlsContainer else { return }
		let insets = UIEdgeInsets(top: controlsContainer.bounds.height + 8, left: 0, bottom: totalsContainer.bounds.height + 16, right: 0)
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
		cell.configure(faceValue: faceValue, sideCount: viewModel.configuration.sideCount, index: indexPath.row)
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
		controlsContainer.backgroundColor = UIColor(white: 1.0, alpha: 0.9)
		controlsContainer.layer.cornerRadius = 10
		view.addSubview(controlsContainer)
		self.controlsContainer = controlsContainer

		notationField.translatesAutoresizingMaskIntoConstraints = false
		notationField.placeholder = "e.g. 6d6, 12d10, 6d6i"
		notationField.autocapitalizationType = .none
		notationField.autocorrectionType = .no
		notationField.clearButtonMode = .whileEditing
		notationField.borderStyle = .roundedRect
		notationField.delegate = self
		notationField.accessibilityLabel = "Dice notation input"
		notationField.accessibilityHint = "Enter notation like 6d6 or 6d6i"
		notationField.accessibilityIdentifier = "notationField"
		notationField.addTarget(self, action: #selector(notationEditingChanged), for: .editingChanged)
		configureNotationInputAccessory()

		let rollButton = UIButton(type: .system)
		rollButton.translatesAutoresizingMaskIntoConstraints = false
		rollButton.setTitle("Roll", for: .normal)
		rollButton.addTarget(self, action: #selector(rollFromInput), for: .touchUpInside)
		rollButton.accessibilityLabel = "Roll dice"
		rollButton.accessibilityIdentifier = "rollButton"
		rollButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
		rollButton.titleLabel?.adjustsFontForContentSizeCategory = true

		presetsButton.translatesAutoresizingMaskIntoConstraints = false
		presetsButton.setTitle("Presets", for: .normal)
		presetsButton.showsMenuAsPrimaryAction = true
		presetsButton.menu = makePresetMenu()
		presetsButton.accessibilityLabel = "Dice presets"
		presetsButton.accessibilityIdentifier = "presetsButton"
		presetsButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
		presetsButton.titleLabel?.adjustsFontForContentSizeCategory = true

		historyButton.translatesAutoresizingMaskIntoConstraints = false
		historyButton.setTitle("History", for: .normal)
		historyButton.addTarget(self, action: #selector(showHistory), for: .touchUpInside)
		historyButton.accessibilityLabel = "Roll history"
		historyButton.accessibilityHint = "Open session history and export options"
		historyButton.accessibilityIdentifier = "historyButton"
		historyButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
		historyButton.titleLabel?.adjustsFontForContentSizeCategory = true

		animationButton.translatesAutoresizingMaskIntoConstraints = false
		animationButton.addTarget(self, action: #selector(toggleAnimations), for: .touchUpInside)
		animationButton.accessibilityLabel = "Toggle dice animations"
		animationButton.accessibilityIdentifier = "animationButton"
		animationButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
		animationButton.titleLabel?.adjustsFontForContentSizeCategory = true

		let row = UIStackView(arrangedSubviews: [notationField, rollButton, presetsButton, historyButton, animationButton])
		row.translatesAutoresizingMaskIntoConstraints = false
		row.axis = .horizontal
		row.spacing = 8
		row.alignment = .fill

		validationLabel.translatesAutoresizingMaskIntoConstraints = false
		validationLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
		validationLabel.adjustsFontForContentSizeCategory = true
		validationLabel.textColor = .systemRed
		validationLabel.numberOfLines = 2
		validationLabel.isHidden = true
		validationLabel.accessibilityTraits = .staticText

		totalsContainer.translatesAutoresizingMaskIntoConstraints = false
		totalsContainer.backgroundColor = UIColor(white: 1.0, alpha: 0.9)
		totalsContainer.layer.cornerRadius = 10
		totalsContainer.layer.masksToBounds = true
		view.addSubview(totalsContainer)

		totalsLabel.translatesAutoresizingMaskIntoConstraints = false
		totalsLabel.backgroundColor = .clear
		totalsLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
		totalsLabel.adjustsFontForContentSizeCategory = true
		totalsLabel.numberOfLines = 0
		totalsLabel.textColor = .darkGray
		totalsLabel.textAlignment = .left
		totalsLabel.accessibilityIdentifier = "totalsLabel"

		resetStatsButton.translatesAutoresizingMaskIntoConstraints = false
		resetStatsButton.setTitle("Reset", for: .normal)
		resetStatsButton.addTarget(self, action: #selector(resetStats), for: .touchUpInside)
		resetStatsButton.accessibilityLabel = "Reset statistics"
		resetStatsButton.accessibilityIdentifier = "resetStatsButton"
		resetStatsButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
		resetStatsButton.titleLabel?.adjustsFontForContentSizeCategory = true

		totalsContainer.addSubview(totalsLabel)
		totalsContainer.addSubview(resetStatsButton)

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
			totalsContainer.heightAnchor.constraint(equalToConstant: 92),

			totalsLabel.leadingAnchor.constraint(equalTo: totalsContainer.leadingAnchor, constant: 8),
			totalsLabel.topAnchor.constraint(equalTo: totalsContainer.topAnchor, constant: 8),
			totalsLabel.bottomAnchor.constraint(equalTo: totalsContainer.bottomAnchor, constant: -8),
			totalsLabel.trailingAnchor.constraint(equalTo: resetStatsButton.leadingAnchor, constant: -8),

			resetStatsButton.trailingAnchor.constraint(equalTo: totalsContainer.trailingAnchor, constant: -8),
			resetStatsButton.centerYAnchor.constraint(equalTo: totalsContainer.centerYAnchor),
			resetStatsButton.widthAnchor.constraint(equalToConstant: 52),

			rollButton.widthAnchor.constraint(equalToConstant: 52),
			presetsButton.widthAnchor.constraint(equalToConstant: 72),
			historyButton.widthAnchor.constraint(equalToConstant: 72),
			animationButton.widthAnchor.constraint(equalToConstant: 68),
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
			presetsButton.menu = makePresetMenu()
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
		guard boardSupportedSides.contains(viewModel.configuration.sideCount) else {
			diceBoardView.isHidden = true
			return
		}

		diceBoardView.isHidden = false

		let sideLength = 0.25 * min(collectionView.bounds.width, collectionView.bounds.height)
		let itemCount = collectionView.numberOfItems(inSection: 0)
		var centers: [CGPoint] = []
		var values: [Int] = []
		centers.reserveCapacity(itemCount)
		values.reserveCapacity(itemCount)

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
		}

		diceBoardView.setDice(values: values, centers: centers, sideLength: sideLength, sideCount: viewModel.configuration.sideCount, animated: animated)
	}

	private func makePresetMenu() -> UIMenu {
		let normalActions = (1...10).map { count in
			UIAction(title: "\(count)d6", image: presetIcon(diceCount: count, intuitive: false)) { _ in
				let outcome = self.viewModel.selectPreset(diceCount: count, intuitive: false)
				self.updateNotationField()
				self.clearValidationFeedback()
				self.presetsButton.menu = self.makePresetMenu()
				self.updateTotalsText(outcome: outcome)
				self.collectionView.reloadData()
				self.collectionView.layoutIfNeeded()
				self.updateDiceBoard(animated: self.shouldAnimateBoard)
			}
		}
		let intuitiveActions = (1...10).map { count in
			UIAction(title: "\(count)d6i", image: presetIcon(diceCount: count, intuitive: true)) { _ in
				let outcome = self.viewModel.selectPreset(diceCount: count, intuitive: true)
				self.updateNotationField()
				self.clearValidationFeedback()
				self.presetsButton.menu = self.makePresetMenu()
				self.updateTotalsText(outcome: outcome)
				self.collectionView.reloadData()
				self.collectionView.layoutIfNeeded()
				self.updateDiceBoard(animated: self.shouldAnimateBoard)
			}
		}

		let recentActions = viewModel.recentPresets.prefix(6).map { notation in
			UIAction(title: notation) { _ in
				self.notationField.text = notation
				self.rollFromInput()
			}
		}
		var sections: [UIMenu] = []
		if !recentActions.isEmpty {
			sections.append(UIMenu(title: "Recent", options: .displayInline, children: recentActions))
		}
		sections.append(UIMenu(title: "Normal", options: .displayInline, children: normalActions))
		sections.append(UIMenu(title: "Intuitive", options: .displayInline, children: intuitiveActions))

		return UIMenu(title: "eDice Presets", children: sections)
	}

	private func presetIcon(diceCount: Int, intuitive: Bool) -> UIImage? {
		let size = CGSize(width: 36, height: 24)
		let renderer = UIGraphicsImageRenderer(size: size)
		let dieImage = UIImage(named: "1")
		let visibleDice = max(1, min(diceCount, 10))
		let offset: CGFloat = 2
		let cardSize = CGSize(width: 14, height: 14)
		let totalStackWidth = cardSize.width + CGFloat(visibleDice - 1) * offset
		let startX = max(0, (size.width - totalStackWidth) / 2)
		let baseY = (size.height - cardSize.height) / 2

		return renderer.image { context in
			for index in 0..<visibleDice {
				let x = startX + CGFloat(index) * offset
				let y = baseY - CGFloat(visibleDice - index - 1)
				let rect = CGRect(x: x, y: y, width: cardSize.width, height: cardSize.height)

				UIColor.white.setFill()
				UIColor(white: 0.5, alpha: 1).setStroke()
				let path = UIBezierPath(roundedRect: rect, cornerRadius: 3)
				path.lineWidth = 1
				path.fill()
				path.stroke()

				if let dieImage {
					dieImage.draw(in: rect.insetBy(dx: 2, dy: 2))
				}
			}

			if intuitive {
				let badgeRect = CGRect(x: size.width - 9, y: 1, width: 8, height: 8)
				context.cgContext.setFillColor(UIColor.systemBlue.cgColor)
				context.cgContext.fillEllipse(in: badgeRect)
			}
		}
	}

	private func showInvalidNotationAlert(message: String) {
		let alert = UIAlertController(
			title: "Invalid dice input",
			message: message,
			preferredStyle: .alert
		)
		alert.addAction(UIAlertAction(title: "OK", style: .default))
		present(alert, animated: true)
	}

	@objc private func notationEditingChanged() {
		clearValidationFeedback()
	}

	@objc private func toggleAnimations() {
		viewModel.setAnimationsEnabled(!viewModel.animationsEnabled)
		updateAnimationButtonState()
	}

	@objc private func showHistory() {
		let entries = viewModel.historyEntries
		let alert = UIAlertController(
			title: "Roll History",
			message: formattedHistoryMessage(entries),
			preferredStyle: .actionSheet
		)
		alert.addAction(UIAlertAction(title: "Export Text", style: .default) { _ in
			self.presentExportSheet(content: self.viewModel.exportHistory(format: .text), filename: "dice-history.txt")
		})
		alert.addAction(UIAlertAction(title: "Export CSV", style: .default) { _ in
			self.presentExportSheet(content: self.viewModel.exportHistory(format: .csv), filename: "dice-history.csv")
		})
		alert.addAction(UIAlertAction(title: "Clear History", style: .destructive) { _ in
			self.viewModel.clearHistory()
		})
		alert.addAction(UIAlertAction(title: "Close", style: .cancel))
		if let popover = alert.popoverPresentationController {
			popover.sourceView = historyButton
			popover.sourceRect = historyButton.bounds
		}
		present(alert, animated: true)
	}

	private func formattedHistoryMessage(_ entries: [RollHistoryEntry]) -> String {
		guard !entries.isEmpty else {
			return "No rolls in this session yet."
		}
		let formatter = DateFormatter()
		formatter.dateStyle = .none
		formatter.timeStyle = .short
		return entries.prefix(10).map { entry in
			let mode = entry.intuitive ? "i" : "r"
			return "\(formatter.string(from: entry.timestamp)) \(entry.notation) [\(mode)] = \(entry.sum)"
		}.joined(separator: "\n")
	}

	private func presentExportSheet(content: String, filename: String) {
		let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
		do {
			try content.write(to: temporaryURL, atomically: true, encoding: .utf8)
			let activity = UIActivityViewController(activityItems: [temporaryURL], applicationActivities: nil)
			if let popover = activity.popoverPresentationController {
				popover.sourceView = historyButton
				popover.sourceRect = historyButton.bounds
			}
			present(activity, animated: true)
		} catch {
			let alert = UIAlertController(title: "Export failed", message: "Could not prepare export file.", preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: "OK", style: .default))
			present(alert, animated: true)
		}
	}

	@objc private func resetStats() {
		viewModel.resetStats()
		totalsLabel.text = "  Stats reset"
	}

	private func updateTotalsText(outcome: RollOutcome) {
		totalsLabel.text = viewModel.formattedTotalsText(outcome: outcome, boardSupportedSides: boardSupportedSides)
	}

	private func showValidationError(message: String) {
		validationLabel.text = message
		validationLabel.isHidden = false
		notationField.layer.borderColor = UIColor.systemRed.cgColor
		notationField.layer.borderWidth = 1
		notationField.layer.cornerRadius = 6
		UIAccessibility.post(notification: .announcement, argument: "Invalid dice notation. \(message)")
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
			UIBarButtonItem(title: "Roll", style: .done, target: self, action: #selector(rollFromInput)),
			UIBarButtonItem.flexibleSpace(),
			UIBarButtonItem(barButtonSystemItem: .done, target: notationField, action: #selector(UIResponder.resignFirstResponder)),
		]
		notationField.inputAccessoryView = toolbar
	}

	private var shouldAnimateBoard: Bool {
		boardSupportedSides.contains(viewModel.configuration.sideCount) && viewModel.animationsEnabled
	}

	private func updateAnimationButtonState() {
		let title = viewModel.animationsEnabled ? "Anim On" : "Anim Off"
		animationButton.setTitle(title, for: .normal)
		animationButton.accessibilityValue = viewModel.animationsEnabled ? "On" : "Off"
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

	@IBOutlet weak var diceButton: UIButton!

	override func layoutSubviews() {
		super.layoutSubviews()
		diceButton.frame = contentView.bounds
	}

	func configure(faceValue: Int, sideCount: Int, index: Int) {
		diceButton.accessibilityIdentifier = "dieButton_\(index)"
		diceButton.accessibilityLabel = "Die \(index + 1), value \(faceValue)"
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
			diceButton.setTitleColor(.black, for: .normal)
			diceButton.titleLabel?.font = UIFont.systemFont(ofSize: 36, weight: .bold)
			diceButton.layer.borderColor = UIColor.darkGray.cgColor
			diceButton.layer.borderWidth = 1
			diceButton.layer.cornerRadius = 8
			diceButton.backgroundColor = UIColor(white: 1.0, alpha: 0.8)
		}
	}

	@IBAction func reroll(_ sender: Any) {
		onRequestReroll?()
	}
}
