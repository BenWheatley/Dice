//
//  DiceUITests.swift
//  DiceUITests
//
//  Created by Ben Wheatley on 2018/09/27.
//  Copyright © 2018 Ben Wheatley. All rights reserved.
//

import XCTest

final class DiceUITests: XCTestCase {
	private var app: XCUIApplication!

	override func setUpWithError() throws {
		continueAfterFailure = false
		app = XCUIApplication()
		app.launchArguments = ["-ui-testing", "-reset-state"]
		app.launch()
	}

	func testLaunchAndRollFromNotationInput() {
		let notationField = app.textFields["notationField"]
		let rollButton = app.buttons["rollButton"]
		let totalsLabel = app.staticTexts["totalsLabel"]

		XCTAssertTrue(notationField.waitForExistence(timeout: 5))
		XCTAssertTrue(rollButton.exists)

		replaceNotation(with: "3d6")
		rollButton.tap()

		XCTAssertTrue(totalsLabel.exists)
	}

	func testPresetIntuitiveAndRerollSingleDie() {
		let presetsButton = app.buttons["presetsButton"]
		XCTAssertTrue(presetsButton.waitForExistence(timeout: 5))

		presetsButton.tap()
		app.buttons.matching(identifier: "2d6i").firstMatch.tap()

		let firstDie = app.buttons["dieButton_0"]
		XCTAssertTrue(firstDie.waitForExistence(timeout: 5))
		firstDie.tap()
	}

	func testResetStatsAndToggleAnimations() {
		let animationButton = app.buttons["animationButton"]
		let resetButton = app.buttons["resetStatsButton"]
		let totalsLabel = app.staticTexts["totalsLabel"]

		XCTAssertTrue(animationButton.waitForExistence(timeout: 5))
		animationButton.tap()
		animationButton.tap()

		XCTAssertTrue(resetButton.exists)
		resetButton.tap()
		XCTAssertTrue(totalsLabel.exists)
	}

	private func replaceNotation(with notation: String) {
		let notationField = app.textFields["notationField"]
		notationField.tap()
		let clearButton = notationField.buttons["Clear text"]
		if clearButton.exists {
			clearButton.tap()
		}
		if let current = notationField.value as? String, !current.isEmpty, !current.contains("e.g.") {
			for _ in 0..<current.count {
				notationField.typeText(XCUIKeyboardKey.delete.rawValue)
			}
		}
		notationField.typeText(notation)
	}

}
