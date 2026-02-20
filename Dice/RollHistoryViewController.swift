import UIKit

final class RollHistoryViewController: UITableViewController, UISearchResultsUpdating {
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
