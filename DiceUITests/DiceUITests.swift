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
		let rollButton = app.buttons["rollButton"]
		XCTAssertTrue(rollButton.waitForExistence(timeout: 5))
		rollButton.tap()

		let firstDie = app.buttons["die_0"]
		XCTAssertTrue(firstDie.waitForExistence(timeout: 5))
		firstDie.tap()
		let inspectorSheet = app.otherElements["dieInspectorSheet"]
		XCTAssertTrue(inspectorSheet.waitForExistence(timeout: 5))
		XCTAssertTrue(app.buttons["dieInspectorRerollButton"].waitForExistence(timeout: 2))
	}

	func testToggleAnimationsFromMenu() {
		let menuButton = app.buttons["menuButton"]
		let totalsLabel = app.staticTexts["totalsLabel"]

		XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
		menuButton.tap()
		app.switches["Animations"].tap()

		app.switches["Animations"].tap()
		XCTAssertTrue(totalsLabel.exists)
	}

	func testRollDistributionSheetLifecyclePersistsDismissAndRestore() {
		let sheet = app.otherElements["rollDistributionSheet"]
		XCTAssertTrue(sheet.waitForExistence(timeout: 8))
		sheet.swipeDown()
		XCTAssertTrue(waitForNonExistence(of: sheet, timeout: 5))

		let showStatsButton = app.buttons["showStatsButton"]
		XCTAssertTrue(showStatsButton.waitForExistence(timeout: 5))

		app.terminate()
		app.launchArguments = ["-ui-testing"]
		app.launch()

		let relaunchedShowButton = app.buttons["showStatsButton"]
		XCTAssertTrue(relaunchedShowButton.waitForExistence(timeout: 8))
		relaunchedShowButton.tap()

		let sheetAfterShow = app.otherElements["rollDistributionSheet"]
		XCTAssertTrue(sheetAfterShow.waitForExistence(timeout: 8))
		XCTAssertFalse(app.buttons["showStatsButton"].exists)

		app.terminate()
		app.launchArguments = ["-ui-testing"]
		app.launch()

		let restoredSheet = app.otherElements["rollDistributionSheet"]
		XCTAssertTrue(restoredSheet.waitForExistence(timeout: 8))
		XCTAssertFalse(app.buttons["showStatsButton"].exists)
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

	private func waitForNonExistence(of element: XCUIElement, timeout: TimeInterval) -> Bool {
		let predicate = NSPredicate(format: "exists == false")
		let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
		return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
	}

}
