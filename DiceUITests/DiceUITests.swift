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
		// Launch-budget test controls launch timing itself.
		if !name.contains("testStartupLaunchWithinBudget") {
			app.launch()
		}
	}

	func testStartupLaunchWithinBudget() {
		app.terminate()
		let budgetSeconds = 6.0
		let start = Date()
		app.launch()
		let notationField = app.textFields["notationField"]
		XCTAssertTrue(notationField.waitForExistence(timeout: 8), "Notation field should appear after launch")
		let elapsed = Date().timeIntervalSince(start)
			XCTAssertLessThanOrEqual(
				elapsed,
				budgetSeconds,
				"Startup launch time \(String(format: "%.2f", elapsed))s exceeded budget \(budgetSeconds)s"
			)
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
		let intuitivePreset = app.cells["preset_2d6i"].firstMatch
		XCTAssertTrue(intuitivePreset.waitForExistence(timeout: 5))
		intuitivePreset.tap()

		let firstDie = app.buttons["dieButton_0"]
		XCTAssertTrue(firstDie.waitForExistence(timeout: 5))
		firstDie.tap()
		XCTAssertTrue(app.buttons["Reroll This Die"].waitForExistence(timeout: 2))
		app.buttons["Cancel"].tap()
	}

	func testResetStatsAndToggleAnimations() {
		let menuButton = app.buttons["menuButton"]
		let totalsLabel = app.staticTexts["totalsLabel"]

		XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
		menuButton.tap()
		app.buttons["Animations"].tap()

		menuButton.tap()
		app.buttons["Animations"].tap()

		menuButton.tap()
		app.buttons["Reset"].tap()
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
