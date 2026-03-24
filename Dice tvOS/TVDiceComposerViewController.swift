import UIKit

final class TVDiceComposerViewController: UITableViewController {
	var onApplyConfiguration: ((RollConfiguration) -> Void)?

	private enum Section: Int, CaseIterable {
		case groups
		case actions
	}

	private enum ActionRow: Int, CaseIterable {
		case apply
		case close
	}

	private static let cellReuseIdentifier = "TVDiceComposerCell"

	private var composerState: DiceTokenComposerState

	init(configuration: RollConfiguration) {
		composerState = DiceTokenComposerState(configuration: configuration)
		super.init(style: .grouped)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("tvos.diceComposer.title", comment: "Dice composer title")
		view.backgroundColor = .black
		tableView.backgroundColor = .black
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellReuseIdentifier)
		tableView.rowHeight = 92
		tableView.sectionHeaderHeight = 56
		tableView.sectionFooterHeight = UITableView.automaticDimension
		tableView.estimatedSectionFooterHeight = 64
		tableView.remembersLastFocusedIndexPath = true
		tableView.cellLayoutMarginsFollowReadableWidth = true
		navigationItem.leftBarButtonItem = UIBarButtonItem(
			title: NSLocalizedString("button.close", comment: "Close button title"),
			style: .plain,
			target: self,
			action: #selector(close)
		)
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		Section.allCases.count
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		guard let section = Section(rawValue: section) else { return 0 }
		switch section {
		case .groups:
			return composerState.pools.count + 1
		case .actions:
			return ActionRow.allCases.count
		}
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		guard let section = Section(rawValue: section) else { return nil }
		switch section {
		case .groups:
			return NSLocalizedString("tvos.diceComposer.section.groups", comment: "Dice groups section title")
		case .actions:
			return NSLocalizedString("menu.control.actions", comment: "Generic actions section title")
		}
	}

	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		guard let section = Section(rawValue: section), section == .groups else { return nil }
		return String.localizedStringWithFormat(
			NSLocalizedString("tvos.diceComposer.summary", comment: "Current notation summary"),
			composerState.notation
		)
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellReuseIdentifier, for: indexPath)
		guard let section = Section(rawValue: indexPath.section) else { return cell }

		var content = UIListContentConfiguration.subtitleCell()
		content.textProperties.font = UIFont.preferredFont(forTextStyle: .title3)
		content.secondaryTextProperties.font = UIFont.preferredFont(forTextStyle: .body)
		content.textProperties.color = .white
		content.secondaryTextProperties.color = UIColor(white: 1.0, alpha: 0.72)

		switch section {
		case .groups:
			if isAddGroupRow(indexPath) {
				content.text = NSLocalizedString("tvos.diceComposer.addGroup", comment: "Add group action")
				content.secondaryText = NSLocalizedString("tvos.diceComposer.addGroup.subtitle", comment: "Add group subtitle")
				cell.accessoryType = .none
			} else {
				let pool = composerState.pools[indexPath.row]
				content.text = DiceTokenComposerState.displayTitle(for: pool)
				content.secondaryText = DiceTokenComposerState.displaySubtitle(for: pool)
				cell.accessoryType = .disclosureIndicator
			}
		case .actions:
			content.secondaryText = nil
			switch ActionRow(rawValue: indexPath.row) {
			case .apply:
				content.text = NSLocalizedString("button.apply", comment: "Apply button title")
			case .close:
				content.text = NSLocalizedString("button.close", comment: "Close button title")
			case .none:
				content.text = nil
			}
			cell.accessoryType = .none
		}

		cell.contentConfiguration = content
		cell.tintColor = .systemBlue
		var background = UIBackgroundConfiguration.listCell()
		background.backgroundColor = UIColor(white: 0.12, alpha: 0.96)
		cell.backgroundConfiguration = background
		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard let section = Section(rawValue: indexPath.section) else { return }
		switch section {
		case .groups:
			if isAddGroupRow(indexPath) {
				composerState.addPool()
				tableView.reloadData()
				return
			}
			let editor = TVDicePoolEditorViewController(
				pool: composerState.pools[indexPath.row],
				canRemove: composerState.pools.count > 1
			)
			editor.onUpdatePool = { [weak self] updatedPool in
				guard let self else { return }
				if let updatedPool {
					composerState.replacePool(at: indexPath.row, with: updatedPool)
				} else {
					composerState.removePool(at: indexPath.row)
				}
				tableView.reloadData()
			}
			navigationController?.pushViewController(editor, animated: true)
		case .actions:
			switch ActionRow(rawValue: indexPath.row) {
			case .apply:
				onApplyConfiguration?(composerState.configuration)
				dismiss(animated: true)
			case .close:
				navigationController?.popViewController(animated: true)
			case .none:
				return
			}
		}
	}

	private func isAddGroupRow(_ indexPath: IndexPath) -> Bool {
		indexPath.section == Section.groups.rawValue && indexPath.row == composerState.pools.count
	}

	@objc private func close() {
		navigationController?.popViewController(animated: true)
	}
}
