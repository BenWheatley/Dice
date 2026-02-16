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
	private let notationParser = DiceNotationParser()
	private let preferencesStore = DicePreferencesStore()
	private let appState = DiceAppState()
	private let rollSession = DiceRollSession()

	private let notationField = UITextField()
	private let totalsLabel = UILabel()
	private let totalsContainer = UIView()
	private let resetStatsButton = UIButton(type: .system)
	private let presetsButton = UIButton(type: .system)
	private let diceBoardView = DiceCubeView()
	private var controlsContainer: UIView?

	override func viewDidLoad() {
		super.viewDidLoad()
		restorePreferences()

		collectionView.backgroundColor = UIColor(patternImage: UIImage(named: "stripes")!)
		collectionView.keyboardDismissMode = .onDrag
		configureControls()
		configureDiceBoard()
		updateNotationField()
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
		appState.diceValues.count
	}

	override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! DiceCollectionViewCell
		let faceValue = appState.diceValues[indexPath.row]
		cell.configure(faceValue: faceValue, sideCount: appState.configuration.sideCount)
		cell.onRequestReroll = { [weak self, weak collectionView] in
			guard let self else { return }
			let singleRoll = RollConfiguration(diceCount: 1, sideCount: self.appState.configuration.sideCount, intuitive: self.appState.configuration.intuitive)
			let outcome = self.rollSession.roll(singleRoll)
			guard let newValue = outcome.values.first else { return }
			self.appState.diceValues[indexPath.row] = newValue
			self.appState.stats = DiceStats(outcome: outcome)
			self.updateTotalsText(outcome: outcome)
			collectionView?.reloadItems(at: [indexPath])
			collectionView?.layoutIfNeeded()
				self.updateDiceBoard(animated: self.boardSupportedSides.contains(self.appState.configuration.sideCount))
			}
		return cell
	}

	override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
		if event?.subtype == .motionShake {
			performRoll()
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

		let rollButton = UIButton(type: .system)
		rollButton.translatesAutoresizingMaskIntoConstraints = false
		rollButton.setTitle("Roll", for: .normal)
		rollButton.addTarget(self, action: #selector(rollFromInput), for: .touchUpInside)

		presetsButton.translatesAutoresizingMaskIntoConstraints = false
		presetsButton.setTitle("Presets", for: .normal)
		presetsButton.showsMenuAsPrimaryAction = true
		presetsButton.menu = makePresetMenu()

		let row = UIStackView(arrangedSubviews: [notationField, rollButton, presetsButton])
		row.translatesAutoresizingMaskIntoConstraints = false
		row.axis = .horizontal
		row.spacing = 8
		row.alignment = .fill

		totalsContainer.translatesAutoresizingMaskIntoConstraints = false
		totalsContainer.backgroundColor = UIColor(white: 1.0, alpha: 0.9)
		totalsContainer.layer.cornerRadius = 10
		totalsContainer.layer.masksToBounds = true
		view.addSubview(totalsContainer)

		totalsLabel.translatesAutoresizingMaskIntoConstraints = false
		totalsLabel.backgroundColor = .clear
		totalsLabel.font = UIFont.systemFont(ofSize: 12)
		totalsLabel.numberOfLines = 0
		totalsLabel.textColor = .darkGray
		totalsLabel.textAlignment = .left

		resetStatsButton.translatesAutoresizingMaskIntoConstraints = false
		resetStatsButton.setTitle("Reset", for: .normal)
		resetStatsButton.addTarget(self, action: #selector(resetStats), for: .touchUpInside)

		totalsContainer.addSubview(totalsLabel)
		totalsContainer.addSubview(resetStatsButton)

		controlsContainer.addSubview(row)

		NSLayoutConstraint.activate([
			controlsContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
			controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
			controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

			row.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 8),
			row.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 8),
			row.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -8),
			row.bottomAnchor.constraint(equalTo: controlsContainer.bottomAnchor, constant: -8),

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
		notationField.text = appState.configuration.notation
	}

	@objc private func rollFromInput() {
		guard let text = notationField.text, let parsed = notationParser.parse(text) else {
			showInvalidNotationAlert()
			return
		}
		appState.configuration = parsed
		notationField.resignFirstResponder()
		preferencesStore.addRecentPreset(parsed.notation)
		persistPreferences()
		performRoll()
	}

	private func performRoll() {
		let outcome = rollSession.roll(appState.configuration)
		appState.applyRollOutcome(outcome)
		updateNotationField()
		updateTotalsText(outcome: outcome)
		collectionView.collectionViewLayout.invalidateLayout()
		collectionView.reloadData()
		collectionView.layoutIfNeeded()
		updateDiceBoard(animated: boardSupportedSides.contains(appState.configuration.sideCount))
	}

	private func updateDiceBoard(animated: Bool) {
		guard boardSupportedSides.contains(appState.configuration.sideCount) else {
			diceBoardView.isHidden = true
			return
		}

		diceBoardView.isHidden = false

		let sideLength = 0.25 * min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
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
			values.append(appState.diceValues[row])
		}

		diceBoardView.setDice(values: values, centers: centers, sideLength: sideLength, sideCount: appState.configuration.sideCount, animated: animated)
	}

	private func makePresetMenu() -> UIMenu {
		let normalActions = (1...10).map { count in
			UIAction(title: "\(count)d6", image: presetIcon(diceCount: count, intuitive: false)) { _ in
				self.appState.configuration = RollConfiguration(diceCount: count, sideCount: 6, intuitive: false)
				self.preferencesStore.addRecentPreset(self.appState.configuration.notation)
				self.persistPreferences()
				self.performRoll()
			}
		}
		let intuitiveActions = (1...10).map { count in
			UIAction(title: "\(count)d6i", image: presetIcon(diceCount: count, intuitive: true)) { _ in
				self.appState.configuration = RollConfiguration(diceCount: count, sideCount: 6, intuitive: true)
				self.preferencesStore.addRecentPreset(self.appState.configuration.notation)
				self.persistPreferences()
				self.performRoll()
			}
		}

		return UIMenu(title: "eDice Presets", children: [
			UIMenu(title: "Normal", options: .displayInline, children: normalActions),
			UIMenu(title: "Intuitive", options: .displayInline, children: intuitiveActions),
		])
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

	private func showInvalidNotationAlert() {
		let alert = UIAlertController(
			title: "Invalid dice input",
			message: "Use NdM or N (for d6), optionally with i. Examples: 6d6, 8d10, 6d6i, 20",
			preferredStyle: .alert
		)
		alert.addAction(UIAlertAction(title: "OK", style: .default))
		present(alert, animated: true)
	}

	@objc private func resetStats() {
		rollSession.reset()
		totalsLabel.text = "  Stats reset"
	}

	private func updateTotalsText(outcome: RollOutcome) {
		var lines: [String] = []
		lines.append("Mode: \(appState.configuration.notation)")

		if appState.configuration.diceCount > 1 {
			let localCounts = formattedCounts(outcome.localTotals)
			if !localCounts.isEmpty {
				lines.append("Roll counts: \(localCounts)")
			}
			lines.append("Roll sum: \(outcome.sum)")
		}

		let sessionCounts = formattedCounts(outcome.sessionTotals)
		if !sessionCounts.isEmpty {
			lines.append("Session counts: \(sessionCounts)")
		}
		lines.append("Session total dice rolled: \(outcome.totalRolls)")

		totalsLabel.text = "  " + lines.joined(separator: "\n  ")
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

	private func restorePreferences() {
		let preferences = preferencesStore.load()
		if let parsed = notationParser.parse(preferences.lastNotation) {
			appState.configuration = parsed
		}
	}

	private func persistPreferences() {
		let preferences = DiceUserPreferences(
			lastNotation: appState.configuration.notation,
			recentPresets: preferencesStore.load().recentPresets
		)
		preferencesStore.save(preferences)
	}
}

extension DiceCollectionViewController: UICollectionViewDelegateFlowLayout {
	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
		4
	}

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
		4
	}

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		let sideLength = floor(0.25 * min(UIScreen.main.bounds.width, UIScreen.main.bounds.height))
		return CGSize(width: sideLength, height: sideLength)
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

	func configure(faceValue: Int, sideCount: Int) {
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
