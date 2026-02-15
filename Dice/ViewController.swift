//
//  ViewController.swift
//  Dice
//
//  Created by Ben Wheatley on 2018/09/27.
//  Copyright © 2018 Ben Wheatley. All rights reserved.
//

import UIKit
import SceneKit

private let reuseIdentifier = "DiceCell"

private struct RollConfiguration {
	let diceCount: Int
	let sideCount: Int
	let intuitive: Bool

	var notation: String {
		"\(diceCount)d\(sideCount)\(intuitive ? "i" : "")"
	}
}

private struct RollOutcome {
	let values: [Int]
	let localTotals: [Int]
	let sessionTotals: [Int]
	let totalRolls: Int
	let sum: Int
}

private final class DiceRollSession {
	private var persistentTotals: [Int] = []
	private var sortedTotals: [Int] = []
	private var totalRolls = 0
	private var wasIntuitive = false

	func roll(_ configuration: RollConfiguration) -> RollOutcome {
		if configuration.intuitive != wasIntuitive {
			persistentTotals = []
			sortedTotals = []
			totalRolls = 0
			wasIntuitive = configuration.intuitive
		}

		ensureCapacity(configuration.sideCount)
		sortedTotals = Array(persistentTotals.prefix(configuration.sideCount)).sorted(by: >)

		var values: [Int] = []
		values.reserveCapacity(configuration.diceCount)
		var localTotals = Array(repeating: 0, count: configuration.sideCount)

		for _ in 0..<configuration.diceCount {
			let roll = getDiceRoll(sideCount: configuration.sideCount, numDiceBeingRolled: configuration.diceCount, intuitive: configuration.intuitive)
			values.append(roll)
			let index = roll - 1
			localTotals[index] += 1
			persistentTotals[index] += 1
			totalRolls += 1
		}

		let sessionTotals = Array(persistentTotals.prefix(configuration.sideCount))
		sortedTotals = sessionTotals.sorted(by: >)
		let sum = values.reduce(0, +)

		return RollOutcome(values: values, localTotals: localTotals, sessionTotals: sessionTotals, totalRolls: totalRolls, sum: sum)
	}

	func reset() {
		persistentTotals = []
		sortedTotals = []
		totalRolls = 0
	}

	private func ensureCapacity(_ sideCount: Int) {
		if persistentTotals.count < sideCount {
			persistentTotals += Array(repeating: 0, count: sideCount - persistentTotals.count)
		}
		if sortedTotals.count < sideCount {
			sortedTotals += Array(repeating: 0, count: sideCount - sortedTotals.count)
		}
	}

	private func getDiceRoll(sideCount: Int, numDiceBeingRolled: Int, intuitive: Bool) -> Int {
		if totalRolls == 0 || !intuitive {
			return Int.random(in: 1...sideCount)
		}

		let localTotalRolls = persistentTotals.prefix(sideCount).reduce(0, +)
		if localTotalRolls == 0 {
			return Int.random(in: 1...sideCount)
		}

		let leastRolled = sortedTotals.count >= sideCount ? sortedTotals[sideCount - 1] : 0
		var rollBoundaries = Array(repeating: 0.0, count: sideCount)
		var scaleFactor = 0.0

		for index in 0..<sideCount {
			let count = persistentTotals[index]
			let observedProbability = Double(count) / Double(localTotalRolls)
			var intuitiveProbability = 1.0 - observedProbability
			if count - leastRolled >= numDiceBeingRolled {
				intuitiveProbability = 0
			}
			rollBoundaries[index] = intuitiveProbability
			scaleFactor += intuitiveProbability
		}

		if scaleFactor <= 0 {
			return Int.random(in: 1...sideCount)
		}

		for index in 0..<sideCount {
			rollBoundaries[index] /= scaleFactor
		}

		var sample = Double.random(in: 0..<1)
		var index = 0
		while index < sideCount - 1 && sample >= rollBoundaries[index] {
			sample -= rollBoundaries[index]
			index += 1
		}
		return index + 1
	}
}

class DiceCollectionViewController: UICollectionViewController, UITextFieldDelegate {
	private var configuration = RollConfiguration(diceCount: 6, sideCount: 6, intuitive: false)
	private var diceValues = Array(repeating: 1, count: 6)
	private let rollSession = DiceRollSession()

	private let notationField = UITextField()
	private let totalsLabel = UILabel()
	private let totalsContainer = UIView()
	private let resetStatsButton = UIButton(type: .system)
	private let presetsButton = UIButton(type: .system)
	private var controlsContainer: UIView?

	override func viewDidLoad() {
		super.viewDidLoad()

		collectionView.backgroundColor = UIColor(patternImage: UIImage(named: "stripes")!)
		collectionView.keyboardDismissMode = .onDrag
		configureControls()
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
	}

	override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		diceValues.count
	}

	override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! DiceCollectionViewCell
		let faceValue = diceValues[indexPath.row]
		cell.configure(faceValue: faceValue, sideCount: configuration.sideCount)
		cell.onRequestReroll = { [weak self, weak collectionView] in
			guard let self else { return }
			let singleRoll = RollConfiguration(diceCount: 1, sideCount: self.configuration.sideCount, intuitive: self.configuration.intuitive)
			let outcome = self.rollSession.roll(singleRoll)
			guard let newValue = outcome.values.first else { return }
			self.diceValues[indexPath.row] = newValue
			self.updateTotalsText(outcome: outcome)
			if let rerolledCell = collectionView?.cellForItem(at: indexPath) as? DiceCollectionViewCell {
				rerolledCell.recursiveDiceAnimation(ultimateTarget: newValue, sideCount: self.configuration.sideCount)
			}
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

	private func updateNotationField() {
		notationField.text = configuration.notation
	}

	@objc private func rollFromInput() {
		guard let text = notationField.text, let parsed = parseRollConfiguration(from: text) else {
			showInvalidNotationAlert()
			return
		}
		configuration = parsed
		notationField.resignFirstResponder()
		performRoll()
	}

	private func performRoll() {
		let outcome = rollSession.roll(configuration)
		diceValues = outcome.values
		updateNotationField()
		updateTotalsText(outcome: outcome)
		collectionView.collectionViewLayout.invalidateLayout()
		collectionView.reloadData()
	}

	private func parseRollConfiguration(from text: String) -> RollConfiguration? {
		let sanitized = text.lowercased().replacingOccurrences(of: " ", with: "")
		if sanitized.isEmpty { return nil }

		let intuitive = sanitized.contains("i")
		let withoutIntuitiveFlag = sanitized.replacingOccurrences(of: "i", with: "")

		let diceCount: Int
		let sideCount: Int

		if let dIndex = withoutIntuitiveFlag.firstIndex(of: "d") {
			let dicePart = String(withoutIntuitiveFlag[..<dIndex])
			let sidePart = String(withoutIntuitiveFlag[withoutIntuitiveFlag.index(after: dIndex)...])
			guard let parsedDice = Int(dicePart), let parsedSides = Int(sidePart) else {
				return nil
			}
			diceCount = parsedDice
			sideCount = parsedSides
		} else {
			guard let parsedDice = Int(withoutIntuitiveFlag) else { return nil }
			diceCount = parsedDice
			sideCount = 6
		}

		guard (1...500).contains(diceCount), (2...1000).contains(sideCount) else {
			return nil
		}

		return RollConfiguration(diceCount: diceCount, sideCount: sideCount, intuitive: intuitive)
	}

	private func makePresetMenu() -> UIMenu {
		let normalActions = (1...10).map { count in
			UIAction(title: "\(count)d6", image: presetIcon(diceCount: count, intuitive: false)) { _ in
				self.configuration = RollConfiguration(diceCount: count, sideCount: 6, intuitive: false)
				self.performRoll()
			}
		}
		let intuitiveActions = (1...10).map { count in
			UIAction(title: "\(count)d6i", image: presetIcon(diceCount: count, intuitive: true)) { _ in
				self.configuration = RollConfiguration(diceCount: count, sideCount: 6, intuitive: true)
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
		lines.append("Mode: \(configuration.notation)")

		if configuration.diceCount > 1 {
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
}

extension DiceCollectionViewController: UICollectionViewDelegateFlowLayout {
	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
		4
	}

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
		4
	}

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		let spacing: CGFloat = 4
		let availableWidth = collectionView.bounds.width - collectionView.adjustedContentInset.left - collectionView.adjustedContentInset.right
		let preferredColumns = max(1, Int(ceil(sqrt(Double(diceValues.count)))))
		let columns = min(max(preferredColumns, 3), 8)
		let totalSpacing = spacing * CGFloat(max(0, columns - 1))
		let rawSize = floor((availableWidth - totalSpacing) / CGFloat(columns))
		let clamped = max(92, min(140, rawSize))
		return CGSize(width: clamped, height: clamped)
	}
}

class DiceCollectionViewCell: UICollectionViewCell {
	var onRequestReroll: (() -> Void)?
	private let cubeView = DiceCubeView()

	@IBOutlet weak var diceButton: UIButton!

	override func awakeFromNib() {
		super.awakeFromNib()
		configureCubeView()
	}

	func configure(faceValue: Int, sideCount: Int) {
		setFaceValue(faceValue, sideCount: sideCount)
	}

	private func configureCubeView() {
		guard cubeView.superview == nil else { return }
		cubeView.translatesAutoresizingMaskIntoConstraints = false
		cubeView.isUserInteractionEnabled = false
		diceButton.insertSubview(cubeView, at: 0)
		NSLayoutConstraint.activate([
			cubeView.leadingAnchor.constraint(equalTo: diceButton.leadingAnchor),
			cubeView.trailingAnchor.constraint(equalTo: diceButton.trailingAnchor),
			cubeView.topAnchor.constraint(equalTo: diceButton.topAnchor),
			cubeView.bottomAnchor.constraint(equalTo: diceButton.bottomAnchor),
		])
	}

	private func setFaceValue(_ value: Int, sideCount: Int) {
		if sideCount == 6, (1...6).contains(value) {
			cubeView.isHidden = false
			cubeView.setFaceValue(value)
			diceButton.setTitle(nil, for: .normal)
			diceButton.setImage(nil, for: .normal)
			diceButton.layer.borderWidth = 0
			diceButton.layer.cornerRadius = 0
			diceButton.backgroundColor = .clear
		} else {
			cubeView.isHidden = true
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

	func recursiveDiceAnimation(ultimateTarget: Int, sideCount: Int, stepsRemaining: Int = Constants.rollingAnimationSteps) {
		if sideCount == 6 {
			cubeView.isHidden = false
			cubeView.roll(to: ultimateTarget, duration: Constants.finalRollAnimationTime)
			return
		}

		UIView.animate(
			withDuration: Constants.finalRollAnimationTime / pow(Constants.ithRollAnimationDecayConstant, 1.0 + Double(stepsRemaining)),
			delay: 0.0,
			options: .curveLinear,
			animations: {
				let thisRoll = stepsRemaining == 0 ? ultimateTarget : Int.random(in: 1...sideCount)
				self.setFaceValue(thisRoll, sideCount: sideCount)
				let angle = CGFloat.pi
				self.diceButton.transform = self.diceButton.transform.rotated(by: angle)
			},
			completion: { finished in
				if finished && stepsRemaining > 0 {
					self.recursiveDiceAnimation(ultimateTarget: ultimateTarget, sideCount: sideCount, stepsRemaining: stepsRemaining - 1)
				}
			}
		)
	}

	private struct Constants {
		static let rollingAnimationSteps = 5
		static let finalRollAnimationTime: TimeInterval = 0.6
		static let ithRollAnimationDecayConstant = 1.3
	}
}
