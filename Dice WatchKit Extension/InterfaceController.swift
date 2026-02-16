//
//  InterfaceController.swift
//  Dice WatchKit Extension
//
//  Created by Ben Wheatley on 2018/09/27.
//  Copyright © 2018 Ben Wheatley. All rights reserved.
//

import WatchKit
import Foundation


class InterfaceController: WKInterfaceController {

	private let viewModel = WatchRollViewModel()
	private var rollCount = 0

	@IBOutlet weak var diceButton: WKInterfaceButton!
	@IBOutlet weak var diceView: WKInterfaceImage!

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
		diceButton.setAccessibilityLabel("Roll dice")
		diceButton.setAccessibilityHint("Double tap to roll one die")
		diceView.setAccessibilityLabel("Latest die result")
		addMenuItem(with: .more, title: "Mode", action: #selector(toggleMode))
		roll()
    }

	override func willActivate() {
        super.willActivate()
    }

    override func didDeactivate() {
        super.didDeactivate()
    }

	@IBAction func roll() {
		let outcome = viewModel.roll()
		guard let value = outcome.values.first else { return }
		rollCount += 1
		diceView.setImageNamed("\(value)")
		diceView.setAccessibilityValue("Value \(value)")
		diceButton.setTitle("\(viewModel.currentNotation) • \(rollCount)")
		WKInterfaceDevice.current().play(.click)
	}

	@objc private func toggleMode() {
		viewModel.toggleMode()
		rollCount = 0
		WKInterfaceDevice.current().play(.success)
		roll()
	}
}
