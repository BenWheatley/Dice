import UIKit

final class PresetManagerViewController: UITableViewController {
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
