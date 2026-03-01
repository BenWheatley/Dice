import SwiftUI
import UIKit

final class RollDistributionSheetViewController: UIViewController {
	var onDismiss: (() -> Void)?

	private let titleLabel = UILabel()
	private let summaryLabel = UILabel()
	private let chartContainer = UIView()
	private var chartHostingController: UIHostingController<DiceRollDistributionChartView>?

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .systemBackground
		configureLayout()
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		if isBeingDismissed || navigationController?.isBeingDismissed == true {
			onDismiss?()
		}
	}

	func updateContent(
		title: String,
		summary: String?,
		points: [DiceRollDistributionPoint],
		yAxisTitle: String,
		barColor: UIColor,
		axisColor: UIColor,
		gridColor: UIColor,
		palette: DiceThemePalette
	) {
		titleLabel.text = title
		summaryLabel.text = summary
		summaryLabel.isHidden = summary?.isEmpty ?? true
		titleLabel.textColor = palette.secondaryTextColor
		summaryLabel.textColor = palette.primaryTextColor

		let rootView = DiceRollDistributionChartView(
			points: points,
			yAxisTitle: yAxisTitle,
			barColor: Color(uiColor: barColor),
			axisColor: Color(uiColor: axisColor),
			gridColor: Color(uiColor: gridColor)
		)

		if let chartHostingController {
			chartHostingController.rootView = rootView
			return
		}

		let hostingController = UIHostingController(rootView: rootView)
		hostingController.view.backgroundColor = .clear
		hostingController.view.translatesAutoresizingMaskIntoConstraints = false
		addChild(hostingController)
		chartContainer.addSubview(hostingController.view)
		NSLayoutConstraint.activate([
			hostingController.view.leadingAnchor.constraint(equalTo: chartContainer.leadingAnchor),
			hostingController.view.trailingAnchor.constraint(equalTo: chartContainer.trailingAnchor),
			hostingController.view.topAnchor.constraint(equalTo: chartContainer.topAnchor),
			hostingController.view.bottomAnchor.constraint(equalTo: chartContainer.bottomAnchor),
		])
		hostingController.didMove(toParent: self)
		chartHostingController = hostingController
	}

	private func configureLayout() {
		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		titleLabel.font = .preferredFont(forTextStyle: .headline)
		titleLabel.adjustsFontForContentSizeCategory = true
		titleLabel.numberOfLines = 1

		summaryLabel.translatesAutoresizingMaskIntoConstraints = false
		summaryLabel.font = .preferredFont(forTextStyle: .subheadline)
		summaryLabel.adjustsFontForContentSizeCategory = true
		summaryLabel.numberOfLines = 2

		chartContainer.translatesAutoresizingMaskIntoConstraints = false
		chartContainer.backgroundColor = .clear
		chartContainer.isUserInteractionEnabled = false

		view.addSubview(titleLabel)
		view.addSubview(summaryLabel)
		view.addSubview(chartContainer)

		NSLayoutConstraint.activate([
			titleLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
			titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
			titleLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

			summaryLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
			summaryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
			summaryLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

			chartContainer.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
			chartContainer.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
			chartContainer.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 8),
			chartContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
		])
	}
}
