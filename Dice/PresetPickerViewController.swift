import UIKit

final class PresetPickerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
	var onSelectPreset: ((Int, Bool) -> Void)?
	var onSelectNotationPreset: ((String) -> Void)?
	var onSaveCustomPresets: (([DiceSavedPreset]) -> Void)?
	var onCreateCustomPreset: ((String, String) -> Result<Void, DiceInputError>)?

	private let normalTableView = UITableView(frame: .zero, style: .insetGrouped)
	private let intuitiveTableView = UITableView(frame: .zero, style: .insetGrouped)
	private let currentNotation: String
	private var customPresets: [DiceSavedPreset]

	init(currentNotation: String, customPresets: [DiceSavedPreset]) {
		self.currentNotation = currentNotation
		self.customPresets = customPresets
		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

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
		navigationItem.rightBarButtonItem = UIBarButtonItem(
			title: NSLocalizedString("button.manage", comment: "Manage presets button title"),
			style: .plain,
			target: self,
			action: #selector(openPresetManager)
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

	@objc private func openPresetManager() {
		let manager = PresetManagerViewController(
			initialPresets: customPresets,
			currentNotation: currentNotation
		)
		manager.onSave = { [weak self] presets in
			guard let self else { return }
			customPresets = presets
			onSaveCustomPresets?(presets)
		}
		manager.onCreatePreset = { [weak self] title, notation in
			guard let self else { return .failure(.invalidFormat) }
			return onCreateCustomPreset?(title, notation) ?? .failure(.invalidFormat)
		}
		manager.onApplyPreset = { [weak self] notation in
			self?.onSelectNotationPreset?(notation)
			self?.dismiss(animated: true)
		}
		navigationController?.pushViewController(manager, animated: true)
	}

	@objc private func close() {
		dismiss(animated: true)
	}
}
