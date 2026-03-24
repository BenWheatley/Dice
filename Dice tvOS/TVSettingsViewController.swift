import UIKit

final class TVSettingsViewController: UITableViewController {
	enum ModeOption: CaseIterable, Equatable {
		case trueRandom
		case intuitive

		var title: String {
			switch self {
			case .trueRandom:
				return NSLocalizedString("stats.mode.trueRandom", comment: "True random roll mode")
			case .intuitive:
				return NSLocalizedString("stats.mode.intuitive", comment: "Intuitive roll mode")
			}
		}
	}

	private enum Section: Int, CaseIterable {
		case mode
		case texture
		case theme

		var title: String {
			switch self {
			case .mode:
				return NSLocalizedString("menu.control.mode", comment: "Roll mode section title")
			case .texture:
				return NSLocalizedString("menu.control.texture", comment: "Table texture section title")
			case .theme:
				return NSLocalizedString("menu.control.theme", comment: "Theme section title")
			}
		}
	}

	var onSelectMode: ((ModeOption) -> Void)?
	var onSelectTexture: ((DiceTableTexture) -> Void)?
	var onSelectTheme: ((DiceTheme) -> Void)?

	private static let cellReuseIdentifier = "TVSettingsCell"

	private var selectedMode: ModeOption?
	private var selectedTexture: DiceTableTexture
	private var selectedTheme: DiceTheme

	init(mode: ModeOption?, texture: DiceTableTexture, theme: DiceTheme) {
		selectedMode = mode
		selectedTexture = texture
		selectedTheme = theme
		super.init(style: .grouped)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("settings.title", comment: "Settings screen title")
		view.backgroundColor = .black
		tableView.backgroundColor = .black
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellReuseIdentifier)
		tableView.rowHeight = 92
		tableView.sectionHeaderHeight = 56
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
		case .mode:
			return ModeOption.allCases.count
		case .texture:
			return DiceTableTexture.allCases.count
		case .theme:
			return DiceTheme.allCases.count
		}
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		Section(rawValue: section)?.title
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellReuseIdentifier, for: indexPath)
		guard let section = Section(rawValue: indexPath.section) else { return cell }

		var content = cell.defaultContentConfiguration()
		content.textProperties.font = UIFont.preferredFont(forTextStyle: .title3)
		content.textProperties.color = .white
		content.text = title(for: indexPath, in: section)
		cell.contentConfiguration = content
		cell.tintColor = .systemBlue
		let isSelected = isSelected(indexPath: indexPath, in: section)
		cell.accessoryType = isSelected ? .checkmark : .none

		var background = UIBackgroundConfiguration.listCell()
		background.backgroundColor = UIColor(white: 0.12, alpha: 0.96)
		cell.backgroundConfiguration = background
		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard let section = Section(rawValue: indexPath.section) else { return }
		let sectionIndex = indexPath.section
		switch section {
		case .mode:
			let option = ModeOption.allCases[indexPath.row]
			selectedMode = option
			onSelectMode?(option)
		case .texture:
			let texture = DiceTableTexture.allCases[indexPath.row]
			selectedTexture = texture
			onSelectTexture?(texture)
		case .theme:
			let theme = DiceTheme.allCases[indexPath.row]
			selectedTheme = theme
			onSelectTheme?(theme)
		}
		tableView.reloadSections(IndexSet(integer: sectionIndex), with: .none)
	}

	private func title(for indexPath: IndexPath, in section: Section) -> String {
		switch section {
		case .mode:
			return ModeOption.allCases[indexPath.row].title
		case .texture:
			return NSLocalizedString(DiceTableTexture.allCases[indexPath.row].menuTitleKey, comment: "Table texture option")
		case .theme:
			return NSLocalizedString(DiceTheme.allCases[indexPath.row].menuTitleKey, comment: "Theme option")
		}
	}

	private func isSelected(indexPath: IndexPath, in section: Section) -> Bool {
		switch section {
		case .mode:
			let option = ModeOption.allCases[indexPath.row]
			let isSelected = option == selectedMode
			return isSelected
		case .texture:
			let isSelected = DiceTableTexture.allCases[indexPath.row] == selectedTexture
			return isSelected
		case .theme:
			let isSelected = DiceTheme.allCases[indexPath.row] == selectedTheme
			return isSelected
		}
	}

	@objc private func close() {
		dismiss(animated: true)
	}
}
