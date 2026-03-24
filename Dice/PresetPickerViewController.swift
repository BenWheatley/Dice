import UIKit

final class PresetPickerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
	var onSelectNotationPreset: ((String) -> Void)?
	var onSaveCustomPresets: (([DiceSavedPreset]) -> Void)?
	var onCreateCustomPreset: ((String, String) -> Result<Void, DiceInputError>)?

	private static let unifiedPresetsInitializedKey = "Dice.unifiedPresetsInitialized"

#if os(tvOS)
	private let tableView = UITableView(frame: .zero, style: .grouped)
#else
	private let tableView = UITableView(frame: .zero, style: .insetGrouped)
#endif
	private let currentNotation: String
	private var presets: [DiceSavedPreset]
	private let parser = DiceNotationParser()

	init(currentNotation: String, customPresets: [DiceSavedPreset]) {
		self.currentNotation = currentNotation
		let initialized = UserDefaults.standard.bool(forKey: Self.unifiedPresetsInitializedKey)
		self.presets = Self.mergedPresets(saved: customPresets, initialized: initialized)
		super.init(nibName: nil, bundle: nil)
		if !initialized {
			UserDefaults.standard.set(true, forKey: Self.unifiedPresetsInitializedKey)
		}
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("menu.presets.title", comment: "Preset menu title")
#if os(tvOS)
		view.backgroundColor = .black
#else
		view.backgroundColor = .systemBackground
#endif
		navigationItem.leftBarButtonItem = UIBarButtonItem(
			title: NSLocalizedString("button.close", comment: "Close button title"),
			style: .plain,
			target: self,
			action: #selector(close)
		)
		navigationItem.rightBarButtonItem = UIBarButtonItem(
			barButtonSystemItem: .add,
			target: self,
			action: #selector(addPreset)
		)
		configureTableView()

		tableView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(tableView)

		NSLayoutConstraint.activate([
			tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
		])

		preferredContentSize = CGSize(width: 420, height: 500)
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		onSaveCustomPresets?(presets)
	}

	private func configureTableView() {
		tableView.dataSource = self
		tableView.delegate = self
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PresetCell")
		tableView.accessibilityIdentifier = "presetsTable"
#if os(tvOS)
		tableView.backgroundColor = .clear
		tableView.rowHeight = 92
		tableView.sectionHeaderHeight = 56
		tableView.remembersLastFocusedIndexPath = true
		tableView.cellLayoutMarginsFollowReadableWidth = true
#endif
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		presets.count
	}

	func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		NSLocalizedString("menu.presets.all", comment: "All presets section title")
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "PresetCell", for: indexPath)
		let preset = presets[indexPath.row]
		var content = UIListContentConfiguration.subtitleCell()
		content.text = preset.title
		content.secondaryText = preset.notation
#if os(tvOS)
		content.textProperties.color = .white
		content.textProperties.font = UIFont.preferredFont(forTextStyle: .title3)
		content.secondaryTextProperties.color = UIColor(white: 1.0, alpha: 0.72)
		content.secondaryTextProperties.font = UIFont.preferredFont(forTextStyle: .body)
#endif
		cell.contentConfiguration = content
		cell.accessibilityIdentifier = "preset_\(preset.id)"
#if os(tvOS)
		var background = UIBackgroundConfiguration.listCell()
		background.backgroundColor = UIColor(white: 0.12, alpha: 0.96)
		cell.backgroundConfiguration = background
		cell.tintColor = .systemBlue
		cell.accessoryType = .none
#else
		cell.accessoryType = .disclosureIndicator
#endif
		return cell
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		onSelectNotationPreset?(presets[indexPath.row].notation)
		dismiss(animated: true)
	}

#if !os(tvOS)
	func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		let edit = UIContextualAction(style: .normal, title: NSLocalizedString("button.edit", comment: "Edit button title")) { [weak self] _, _, done in
			guard let self else { return }
			presentEditPreset(at: indexPath.row)
			done(true)
		}
		edit.backgroundColor = .systemBlue
		let delete = UIContextualAction(style: .destructive, title: NSLocalizedString("button.delete", comment: "Delete button title")) { [weak self] _, _, done in
			guard let self else { return }
			presets.remove(at: indexPath.row)
			tableView.deleteRows(at: [indexPath], with: .automatic)
			done(true)
		}
		let config = UISwipeActionsConfiguration(actions: [delete, edit])
		config.performsFirstActionWithFullSwipe = false
		return config
	}
#endif

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
			if parser.parse(notation) == nil {
				presentInlineError(NSLocalizedString("error.input.invalidFormat", comment: "Invalid format fallback"))
				return
			}
			if case .failure(let error) = onCreateCustomPreset?(title, notation) {
				presentInlineError(error.userMessage)
				return
			}
			presets.append(DiceSavedPreset(title: title, notation: notation))
			tableView.reloadData()
		})
		present(alert, animated: true)
	}

	@objc private func close() {
		dismiss(animated: true)
	}

	private func presentEditPreset(at index: Int) {
		guard presets.indices.contains(index) else { return }
		let existing = presets[index]
		let alert = UIAlertController(
			title: NSLocalizedString("presets.manage.edit.title", comment: "Edit preset dialog title"),
			message: NSLocalizedString("presets.manage.edit.message", comment: "Edit preset dialog message"),
			preferredStyle: .alert
		)
		alert.addTextField { field in
			field.placeholder = NSLocalizedString("presets.manage.field.title", comment: "Preset title field placeholder")
			field.text = existing.title
		}
		alert.addTextField { field in
			field.placeholder = NSLocalizedString("presets.manage.field.notation", comment: "Preset notation field placeholder")
			field.text = existing.notation
			field.autocapitalizationType = .none
			field.autocorrectionType = .no
		}
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.cancel", comment: "Cancel action"), style: .cancel))
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.save", comment: "Save button title"), style: .default) { [weak self, weak alert] _ in
			guard let self, let fields = alert?.textFields, fields.count == 2 else { return }
			let result = Self.updatedPreset(
				from: existing,
				rawTitle: fields[0].text ?? "",
				rawNotation: fields[1].text ?? ""
			)
			switch result {
			case let .success(updated):
				presets[index] = updated
				tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
			case let .failure(error):
				presentInlineError(error.userMessage)
			}
		})
		present(alert, animated: true)
	}

	private func presentInlineError(_ message: String) {
		let alert = UIAlertController(
			title: NSLocalizedString("alert.invalid.title", comment: "Invalid notation alert title"),
			message: message,
			preferredStyle: .alert
		)
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.ok", comment: "Generic confirmation button"), style: .default))
		present(alert, animated: true)
	}

	static func mergedPresets(saved: [DiceSavedPreset], initialized: Bool) -> [DiceSavedPreset] {
		guard !initialized else { return saved }
		var merged = builtInPresets()
		let existingNotations = Set(merged.map { $0.notation.lowercased() })
		for preset in saved where !existingNotations.contains(preset.notation.lowercased()) {
			merged.append(preset)
		}
		return merged
	}

	static func updatedPreset(from existing: DiceSavedPreset, rawTitle: String, rawNotation: String) -> Result<DiceSavedPreset, DiceInputError> {
		let parser = DiceNotationParser()
		let notation = rawNotation.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !notation.isEmpty else {
			return .failure(.invalidFormat)
		}
		switch parser.parseResult(notation) {
		case let .failure(error):
			return .failure(error)
		case .success:
			let trimmedTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
			let title = trimmedTitle.isEmpty ? notation : trimmedTitle
			return .success(DiceSavedPreset(id: existing.id, title: title, notation: notation, pinned: existing.pinned))
		}
	}

	static func builtInPresets() -> [DiceSavedPreset] {
		[
			DiceSavedPreset(id: "builtin-1d6", title: "1d6", notation: "1d6"),
			DiceSavedPreset(id: "builtin-2d6", title: "2d6", notation: "2d6"),
			DiceSavedPreset(id: "builtin-3d6", title: "3d6", notation: "3d6"),
			DiceSavedPreset(id: "builtin-4d6", title: "4d6", notation: "4d6"),
			DiceSavedPreset(id: "builtin-1d6i", title: "1d6i", notation: "1d6i"),
			DiceSavedPreset(id: "builtin-mixed-color", title: "d6(red)+d20(green)", notation: "d6(red)+d20(green)"),
			DiceSavedPreset(id: "builtin-mixed-style", title: "d6(blue)+d4(red)", notation: "d6(blue)+d4(red)")
		]
	}
}
