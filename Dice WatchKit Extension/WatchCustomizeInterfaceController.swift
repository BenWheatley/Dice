import Foundation
import WatchKit

final class WatchCustomizeInterfaceController: WKInterfaceController {
	private let configurationSync = WatchSingleDieConfigurationSyncBridge.shared
	private var customizationState = WatchSingleDieCustomizationState(configuration: WatchSingleDieConfiguration.watchDefault)

	@IBOutlet private weak var sideCountPicker: WKInterfacePicker!
	@IBOutlet private weak var colorButton: WKInterfaceButton!
	@IBOutlet private weak var backgroundButton: WKInterfaceButton!
	@IBOutlet private weak var modeButton: WKInterfaceButton!

	override func awake(withContext context: Any?) {
		super.awake(withContext: context)
		setTitle("Customize")
		if let configuration = context as? WatchSingleDieConfiguration {
			customizationState = WatchSingleDieCustomizationState(configuration: configuration)
		} else {
			customizationState = WatchSingleDieCustomizationState(configuration: configurationSync.currentConfiguration())
		}
		configureSidePicker()
		applyUIState()
	}

	@IBAction func sideCountPickerChanged(_ pickerIndex: Int) {
		customizationState.setSideCountFromPickerIndex(pickerIndex)
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

	private func configureSidePicker() {
		let items = WatchSingleDieCustomizationState.pickerSideCounts.map { sideCount -> WKPickerItem in
			let item = WKPickerItem()
			item.title = "d\(sideCount)"
			return item
		}
		sideCountPicker.setItems(items)
		sideCountPicker.setSelectedItemIndex(customizationState.sidePickerIndex)
	}

	private func applyUIState() {
		sideCountPicker.setSelectedItemIndex(customizationState.sidePickerIndex)
		colorButton.setTitle("Color: \(customizationState.colorToken)")
		backgroundButton.setTitle("Background: \(customizationState.backgroundToken)")
		modeButton.setTitle("Roll Mode: \(customizationState.modeLabel)")
	}
}
