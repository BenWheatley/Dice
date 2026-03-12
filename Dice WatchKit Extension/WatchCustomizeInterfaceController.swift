import Foundation
import WatchKit

final class WatchCustomizeInterfaceController: WKInterfaceController {
	private let configurationSync = WatchSingleDieConfigurationSyncBridge.shared
	private var customizationState = WatchSingleDieCustomizationState(configuration: WatchSingleDieConfiguration.watchDefault)

	@IBOutlet private weak var sideCountPicker: WKInterfacePicker!
	@IBOutlet private weak var sideD2Button: WKInterfaceButton!
	@IBOutlet private weak var sideD4Button: WKInterfaceButton!
	@IBOutlet private weak var sideD6Button: WKInterfaceButton!
	@IBOutlet private weak var sideD8Button: WKInterfaceButton!
	@IBOutlet private weak var sideD10Button: WKInterfaceButton!
	@IBOutlet private weak var sideD12Button: WKInterfaceButton!
	@IBOutlet private weak var sideD20Button: WKInterfaceButton!
	@IBOutlet private weak var colorButton: WKInterfaceButton!
	@IBOutlet private weak var modeButton: WKInterfaceButton!

	override func awake(withContext context: Any?) {
		super.awake(withContext: context)
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

	@IBAction func selectSideD2() { selectQuickChipSide(2) }
	@IBAction func selectSideD4() { selectQuickChipSide(4) }
	@IBAction func selectSideD6() { selectQuickChipSide(6) }
	@IBAction func selectSideD8() { selectQuickChipSide(8) }
	@IBAction func selectSideD10() { selectQuickChipSide(10) }
	@IBAction func selectSideD12() { selectQuickChipSide(12) }
	@IBAction func selectSideD20() { selectQuickChipSide(20) }

	private func selectQuickChipSide(_ sideCount: Int) {
		customizationState.setSideCount(sideCount)
		persistCustomization()
	}

	@IBAction func cycleColor() {
		customizationState.cycleColorForward()
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
		updateQuickChipTitles()
		colorButton.setTitle("Color: \(customizationState.colorToken)")
		modeButton.setTitle("Mode: \(customizationState.modeToken)")
	}

	private func updateQuickChipTitles() {
		updateQuickChipTitle(for: sideD2Button, sideCount: 2)
		updateQuickChipTitle(for: sideD4Button, sideCount: 4)
		updateQuickChipTitle(for: sideD6Button, sideCount: 6)
		updateQuickChipTitle(for: sideD8Button, sideCount: 8)
		updateQuickChipTitle(for: sideD10Button, sideCount: 10)
		updateQuickChipTitle(for: sideD12Button, sideCount: 12)
		updateQuickChipTitle(for: sideD20Button, sideCount: 20)
	}

	private func updateQuickChipTitle(for button: WKInterfaceButton, sideCount: Int) {
		let selectedPrefix = customizationState.isQuickChipSelected(sideCount) ? "* " : ""
		button.setTitle("\(selectedPrefix)d\(sideCount)")
	}
}
