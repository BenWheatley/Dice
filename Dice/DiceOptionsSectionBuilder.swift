import UIKit

struct DiceOptionsSectionBuilder {
	let stackView: UIStackView

	func addSwitchRow(title: String, isOn: Bool, action: @escaping (Bool) -> Void) {
		let row = UIStackView()
		row.axis = .horizontal
		row.alignment = .center
		row.spacing = 12
		let label = UILabel()
		label.text = title
		label.numberOfLines = 0
		let toggle = UISwitch()
		toggle.isOn = isOn
		toggle.accessibilityLabel = title
		toggle.addAction(UIAction { _ in action(toggle.isOn) }, for: .valueChanged)
		row.addArrangedSubview(label)
		row.addArrangedSubview(toggle)
		stackView.addArrangedSubview(row)
	}

	func addSegmentRow(title: String, items: [String], selectedIndex: Int, action: @escaping (Int) -> Void) {
		let container = UIStackView()
		container.axis = .vertical
		container.spacing = 8
		let label = UILabel()
		label.text = title
		let segmented = UISegmentedControl(items: items)
		segmented.selectedSegmentIndex = selectedIndex
		segmented.addAction(UIAction { _ in action(segmented.selectedSegmentIndex) }, for: .valueChanged)
		container.addArrangedSubview(label)
		container.addArrangedSubview(segmented)
		stackView.addArrangedSubview(container)
	}

	func addActionButton(title: String, destructive: Bool = false, action: @escaping () -> Void) {
		let button = UIButton(type: .system)
		button.setTitle(title, for: .normal)
		button.contentHorizontalAlignment = .leading
		if destructive {
			button.setTitleColor(.systemRed, for: .normal)
		}
		button.addAction(UIAction { _ in action() }, for: .touchUpInside)
		stackView.addArrangedSubview(button)
	}
}
