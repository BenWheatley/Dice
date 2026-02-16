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
		app.launch()
	}

	func testLaunchAndRollFromNotationInput() {
		let notationField = app.textFields["notationField"]
		let rollButton = app.buttons["rollButton"]
		let totalsLabel = app.staticTexts["totalsLabel"]

		XCTAssertTrue(notationField.waitForExistence(timeout: 3))
		XCTAssertTrue(rollButton.exists)

		replaceNotation(with: "3d6")
		rollButton.tap()

		XCTAssertTrue(totalsLabel.label.contains("Mode: 3d6"))
	}

	func testPresetIntuitiveAndRerollSingleDie() {
		let presetsButton = app.buttons["presetsButton"]
		XCTAssertTrue(presetsButton.waitForExistence(timeout: 3))

		presetsButton.tap()
		app.buttons["2d6i"].tap()

		let totalsLabel = app.staticTexts["totalsLabel"]
		XCTAssertTrue(totalsLabel.label.contains("Mode: 2d6i"))

		let firstDie = app.buttons["dieButton_0"]
		XCTAssertTrue(firstDie.waitForExistence(timeout: 3))
		firstDie.tap()
	}

	func testResetStatsAndToggleAnimations() {
		let animationButton = app.buttons["animationButton"]
		let resetButton = app.buttons["resetStatsButton"]
		let totalsLabel = app.staticTexts["totalsLabel"]

		XCTAssertTrue(animationButton.waitForExistence(timeout: 3))
		animationButton.tap()
		animationButton.tap()

		XCTAssertTrue(resetButton.exists)
		resetButton.tap()
		XCTAssertTrue(totalsLabel.label.contains("Stats reset"))
	}

	private func replaceNotation(with notation: String) {
		let notationField = app.textFields["notationField"]
		notationField.tap()
		if let current = notationField.value as? String {
			for _ in 0..<current.count {
				notationField.typeText(XCUIKeyboardKey.delete.rawValue)
			}
		}
		notationField.typeText(notation)
	}
}
