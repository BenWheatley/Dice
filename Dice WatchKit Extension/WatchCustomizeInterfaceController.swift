import Foundation
import WatchKit

final class WatchCustomizeInterfaceController: WKInterfaceController {
	private let configurationSync = WatchSingleDieConfigurationSyncBridge.shared
	private var customizationState = WatchSingleDieCustomizationState(configuration: WatchSingleDieConfiguration.watchDefault)

	@IBOutlet private weak var sideCountValueLabel: WKInterfaceLabel!
	@IBOutlet private weak var decrementSideCountButton: WKInterfaceButton!
	@IBOutlet private weak var incrementSideCountButton: WKInterfaceButton!
	@IBOutlet private weak var colorButton: WKInterfaceButton!
	@IBOutlet private weak var backgroundButton: WKInterfaceButton!
	@IBOutlet private weak var modeButton: WKInterfaceButton!
	@IBOutlet private weak var doneButton: WKInterfaceButton!

	override func awake(withContext context: Any?) {
		super.awake(withContext: context)
		setTitle("Customize")
		if let configuration = context as? WatchSingleDieConfiguration {
			customizationState = WatchSingleDieCustomizationState(configuration: configuration)
		} else {
			customizationState = WatchSingleDieCustomizationState(configuration: configurationSync.currentConfiguration())
		}
		applyUIState()
	}

	@IBAction func decrementSideCount() {
		customizationState.setSideCount(customizationState.sideCount - 1)
		persistCustomization()
	}

	@IBAction func incrementSideCount() {
		customizationState.setSideCount(customizationState.sideCount + 1)
		persistCustomization()
	}

	@IBAction func cycleColor() {
		customizationState.cycleColorForward()
		persistCustomization()
	}

	@IBAction func cycleBackground() {
		customizationState.cycleBackgroundForward()
		persistCustomization()
	}

	@IBAction func toggleMode() {
		customizationState.toggleMode()
		persistCustomization()
	}

	@IBAction func closeCustomize() {
		pop()
	}

	private func persistCustomization() {
		configurationSync.updateLocalConfiguration { [customizationState] configuration in
			customizationState.apply(to: &configuration)
		}
		applyUIState()
	}

	private func applyUIState() {
		sideCountValueLabel.setText(customizationState.sideToken)
		decrementSideCountButton.setEnabled(customizationState.sideCount > DiceSingleDieSceneGeometryFactory.minimumSideCount)
		incrementSideCountButton.setEnabled(customizationState.sideCount < DiceSingleDieSceneGeometryFactory.maximumSideCount)
		colorButton.setTitle("Color: \(customizationState.colorToken)")
		backgroundButton.setTitle("Background: \(customizationState.backgroundToken)")
		modeButton.setTitle("Mode: \(customizationState.modeLabel)")
		doneButton.setTitle("Done")
	}
}
