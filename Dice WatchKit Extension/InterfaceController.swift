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

	private let rollSession = DiceRollSession()
	private var configuration = RollConfiguration(diceCount: 1, sideCount: 6, intuitive: false)

	@IBOutlet weak var diceButton: WKInterfaceButton!
	@IBOutlet weak var diceView: WKInterfaceImage!

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
		roll()
    }

	override func willActivate() {
        super.willActivate()
    }

    override func didDeactivate() {
        super.didDeactivate()
    }

	@IBAction func roll() {
		let outcome = rollSession.roll(configuration)
		guard let value = outcome.values.first else { return }
		diceView.setImageNamed("\(value)")
	}

}
