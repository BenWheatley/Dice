import UIKit

final class TVDicePoolEditorViewController: UITableViewController {
	var onUpdatePool: ((DicePool?) -> Void)?

	private enum Section: Int, CaseIterable {
		case count
		case sides
		case mode
		case color
		case actions
	}

	private enum ActionRow: Int, CaseIterable {
		case remove
	}

	private static let stepperReuseIdentifier = "TVStepperCell"
	private static let optionReuseIdentifier = "TVPoolOptionCell"

	private var pool: DicePool
	private let canRemove: Bool
	private let composerState = DiceTokenComposerState(configuration: RollConfiguration(diceCount: 1, sideCount: 6, intuitive: false))

	init(pool: DicePool, canRemove: Bool) {
		self.pool = pool
		self.canRemove = canRemove
		super.init(style: .grouped)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = DiceTokenComposerState.displayTitle(for: pool)
		view.backgroundColor = .black
		tableView.backgroundColor = .black
		tableView.register(TVStepperTableViewCell.self, forCellReuseIdentifier: Self.stepperReuseIdentifier)
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.optionReuseIdentifier)
		tableView.rowHeight = UITableView.automaticDimension
		tableView.estimatedRowHeight = 116
		tableView.sectionHeaderHeight = 56
		tableView.remembersLastFocusedIndexPath = true
		tableView.cellLayoutMarginsFollowReadableWidth = true
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		Section.allCases.count
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		guard let section = Section(rawValue: section) else { return 0 }
		switch section {
		case .count, .sides:
			return 1
		case .mode:
			return 2
		case .color:
			return DiceDieColorPreset.allCases.count + 1
		case .actions:
			return canRemove ? ActionRow.allCases.count : 0
		}
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		guard let section = Section(rawValue: section) else { return nil }
		switch section {
		case .count:
			return NSLocalizedString("tvos.diceComposer.section.count", comment: "Dice count section title")
		case .sides:
			return NSLocalizedString("tvos.diceComposer.section.sides", comment: "Dice sides section title")
		case .mode:
			return NSLocalizedString("menu.control.mode", comment: "Roll mode section title")
		case .color:
			return NSLocalizedString("die.options.color", comment: "Die color section title")
		case .actions:
			return NSLocalizedString("menu.control.actions", comment: "Generic actions section title")
		}
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		guard let section = Section(rawValue: indexPath.section) else {
			return UITableViewCell()
		}
		switch section {
		case .count:
			return makeCountCell(for: tableView, indexPath: indexPath)
		case .sides:
			return makeSidesCell(for: tableView, indexPath: indexPath)
		case .mode:
			return makeOptionCell(
				for: tableView,
				title: modeTitle(for: indexPath.row),
				isSelected: pool.intuitive == (indexPath.row == 1),
				isDestructive: false
			)
		case .color:
			return makeOptionCell(
				for: tableView,
				title: colorTitle(for: indexPath.row),
				isSelected: selectedColorIndex == indexPath.row,
				isDestructive: false
			)
		case .actions:
			return makeOptionCell(
				for: tableView,
				title: NSLocalizedString("button.delete", comment: "Delete button title"),
				isSelected: false,
				isDestructive: true
			)
		}
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard let section = Section(rawValue: indexPath.section) else { return }
		switch section {
		case .count, .sides:
			return
		case .mode:
			pool = DicePool(diceCount: pool.diceCount, sideCount: pool.sideCount, intuitive: indexPath.row == 1, colorTag: pool.colorTag)
			persist()
			tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
		case .color:
			let nextColor = colorPreset(for: indexPath.row)
			pool = DicePool(diceCount: pool.diceCount, sideCount: pool.sideCount, intuitive: pool.intuitive, colorTag: nextColor?.notationName)
			persist()
			tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
		case .actions:
			onUpdatePool?(nil)
			navigationController?.popViewController(animated: true)
		}
	}

	private func makeCountCell(for tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: Self.stepperReuseIdentifier, for: indexPath) as! TVStepperTableViewCell
		cell.configure(
			title: NSLocalizedString("tvos.diceComposer.count.title", comment: "Dice count control title"),
			value: String.localizedStringWithFormat(NSLocalizedString("tvos.diceComposer.count.value", comment: "Dice count value"), pool.diceCount),
			canDecrement: pool.diceCount > 1,
			canIncrement: pool.diceCount < 30
		)
		cell.onDecrement = { [weak self] in
			self?.adjustCount(delta: -1)
		}
		cell.onIncrement = { [weak self] in
			self?.adjustCount(delta: 1)
		}
		return cell
	}

	private func makeSidesCell(for tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: Self.stepperReuseIdentifier, for: indexPath) as! TVStepperTableViewCell
		let values = DiceTokenComposerState.commonSideCounts
		let currentIndex = values.firstIndex(of: pool.sideCount) ?? (values.firstIndex(of: 6) ?? 0)
		cell.configure(
			title: NSLocalizedString("tvos.diceComposer.sides.title", comment: "Dice side control title"),
			value: String.localizedStringWithFormat(NSLocalizedString("tvos.diceComposer.sides.value", comment: "Dice side value"), pool.sideCount),
			canDecrement: currentIndex > 0,
			canIncrement: currentIndex < values.count - 1
		)
		cell.onDecrement = { [weak self] in
			self?.adjustSides(delta: -1)
		}
		cell.onIncrement = { [weak self] in
			self?.adjustSides(delta: 1)
		}
		return cell
	}

	private func makeOptionCell(for tableView: UITableView, title: String, isSelected: Bool, isDestructive: Bool) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: Self.optionReuseIdentifier)
			?? UITableViewCell(style: .default, reuseIdentifier: Self.optionReuseIdentifier)
		var content = cell.defaultContentConfiguration()
		content.text = title
		content.textProperties.font = UIFont.preferredFont(forTextStyle: .title3)
		content.textProperties.color = isDestructive ? .systemRed : .white
		cell.contentConfiguration = content
		cell.accessoryType = isSelected ? .checkmark : .none
		cell.tintColor = .systemBlue
		var background = UIBackgroundConfiguration.listCell()
		background.backgroundColor = UIColor(white: 0.12, alpha: 0.96)
		cell.backgroundConfiguration = background
		return cell
	}

	private func modeTitle(for row: Int) -> String {
		row == 1
			? NSLocalizedString("stats.mode.intuitive", comment: "Intuitive roll mode")
			: NSLocalizedString("stats.mode.trueRandom", comment: "True random roll mode")
	}

	private func colorTitle(for row: Int) -> String {
		guard let preset = colorPreset(for: row) else {
			return NSLocalizedString("tvos.diceComposer.color.default", comment: "Default die color")
		}
		return NSLocalizedString(preset.menuTitleKey, comment: "Die color preset")
	}

	private var selectedColorIndex: Int {
		guard let colorTag = pool.colorTag, let preset = DiceDieColorPreset.fromNotation(colorTag) else { return 0 }
		return DiceDieColorPreset.allCases.firstIndex(of: preset).map { $0 + 1 } ?? 0
	}

	private func colorPreset(for row: Int) -> DiceDieColorPreset? {
		guard row > 0 else { return nil }
		return DiceDieColorPreset.allCases[row - 1]
	}

	private func adjustCount(delta: Int) {
		let nextValue = max(1, min(30, pool.diceCount + delta))
		guard nextValue != pool.diceCount else { return }
		pool = DicePool(diceCount: nextValue, sideCount: pool.sideCount, intuitive: pool.intuitive, colorTag: pool.colorTag)
		persist()
		tableView.reloadSections(IndexSet(integer: Section.count.rawValue), with: .none)
	}

	private func adjustSides(delta: Int) {
		let nextValue = composerState.stepSideCount(from: pool.sideCount, delta: delta)
		guard nextValue != pool.sideCount else { return }
		pool = DicePool(diceCount: pool.diceCount, sideCount: nextValue, intuitive: pool.intuitive, colorTag: pool.colorTag)
		persist()
		tableView.reloadSections(IndexSet(integer: Section.sides.rawValue), with: .none)
	}

	private func persist() {
		title = DiceTokenComposerState.displayTitle(for: pool)
		onUpdatePool?(pool)
	}
}
