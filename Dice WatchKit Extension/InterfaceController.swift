//
//  InterfaceController.swift
//  Dice WatchKit Extension
//
//  Created by Ben Wheatley on 2018/09/27.
//  Copyright © 2018 Ben Wheatley. All rights reserved.
//

import WatchKit
import Foundation
import SceneKit


class InterfaceController: WKInterfaceController {

	private let viewModel = WatchRollViewModel()
	private var rollCount = 0
	private var d6Node = SCNNode()
	private var usesSceneRenderer = false
	private var lowPowerObserver: NSObjectProtocol?
	private let feedbackDevice = WKInterfaceDevice.current()

	@IBOutlet weak var diceButton: WKInterfaceButton!
	@IBOutlet weak var diceView: WKInterfaceImage!
	@IBOutlet weak var diceSceneView: WKInterfaceSCNScene!

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
		diceButton.setAccessibilityLabel("Roll dice")
		diceButton.setAccessibilityHint("Double tap to roll one die")
		diceView.setAccessibilityLabel("Latest die result")
		configureSceneRenderer()
		configurePowerModeObserver()
		addMenuItem(with: .more, title: "Mode", action: #selector(toggleMode))
		roll()
    }

	override func willActivate() {
        super.willActivate()
    }

    override func didDeactivate() {
        super.didDeactivate()
    }

	deinit {
		if let lowPowerObserver {
			NotificationCenter.default.removeObserver(lowPowerObserver)
		}
	}

	@IBAction func roll() {
		let outcome = viewModel.roll()
		guard let value = outcome.values.first else { return }
		rollCount += 1
		playRollStartFeedback()
		if usesSceneRenderer {
			animateD6(to: value) { [weak self] in
				self?.playRollSettleFeedback()
			}
			diceSceneView.setAccessibilityValue("Value \(value)")
			diceView.setHidden(true)
		} else {
			diceView.setImageNamed("\(value)")
			diceView.setAccessibilityValue("Value \(value)")
			diceView.setHidden(false)
			playRollSettleFeedback()
		}
		diceButton.setTitle(viewModel.statusText(lastValue: value))
	}

	@objc private func toggleMode() {
		viewModel.toggleMode()
		rollCount = 0
		feedbackDevice.play(.success)
		roll()
	}

	private func configureSceneRenderer() {
		let scene = SCNScene()
		diceSceneView.scene = scene
		diceSceneView.antialiasingMode = .multisampling2X
		diceSceneView.preferredFramesPerSecond = 30

		let cameraNode = SCNNode()
		cameraNode.camera = SCNCamera()
		cameraNode.position = SCNVector3(0, 0, 6)
		scene.rootNode.addChildNode(cameraNode)

		let keyLight = SCNNode()
		keyLight.light = SCNLight()
		keyLight.light?.type = .omni
		keyLight.light?.intensity = 900
		keyLight.position = SCNVector3(2.5, 3.5, 4.5)
		scene.rootNode.addChildNode(keyLight)

		let ambient = SCNNode()
		ambient.light = SCNLight()
		ambient.light?.type = .ambient
		ambient.light?.intensity = 300
		scene.rootNode.addChildNode(ambient)

		d6Node = makeD6Node()
		scene.rootNode.addChildNode(d6Node)
		diceSceneView.setAccessibilityLabel("Latest die result, 3D preview")
		usesSceneRenderer = true
		diceSceneView.setHidden(false)
		applyPowerModeProfile()
	}

	private func configurePowerModeObserver() {
		lowPowerObserver = NotificationCenter.default.addObserver(
			forName: .NSProcessInfoPowerStateDidChange,
			object: nil,
			queue: .main
		) { [weak self] _ in
			self?.applyPowerModeProfile()
		}
	}

	private func applyPowerModeProfile() {
		guard usesSceneRenderer else { return }
		if ProcessInfo.processInfo.isLowPowerModeEnabled {
			diceSceneView.preferredFramesPerSecond = 15
		} else {
			diceSceneView.preferredFramesPerSecond = 30
		}
	}

	private func makeD6Node() -> SCNNode {
		let sideLength: CGFloat = 1.8
		let geometry = D6SceneKitRenderConfig.beveledCube(sideLength: sideLength)

		let node = SCNNode(geometry: geometry)
		return node
	}

	private func animateD6(to value: Int, completion: (() -> Void)? = nil) {
		let target = orientation(for: value)
		SCNTransaction.begin()
		SCNTransaction.animationDuration = ProcessInfo.processInfo.isLowPowerModeEnabled ? 0.2 : 0.4
		SCNTransaction.completionBlock = completion
		d6Node.eulerAngles = target
		SCNTransaction.commit()
	}

	private func playRollStartFeedback() {
		feedbackDevice.play(.start)
	}

	private func playRollSettleFeedback() {
		feedbackDevice.play(.click)
	}

	private func orientation(for value: Int) -> SCNVector3 {
		let angles = D6FaceOrientation.eulerAngles(for: value)
		return SCNVector3(angles.x, angles.y, angles.z)
	}
}
