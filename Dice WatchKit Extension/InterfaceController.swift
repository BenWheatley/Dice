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
import SpriteKit


class InterfaceController: WKInterfaceController {
	private enum WatchRollFeedbackProfile {
		case trueRandom
		case intuitive
	}

	private let configurationSync = WatchSingleDieConfigurationSyncBridge.shared
	private lazy var viewModel = WatchRollViewModel(
		isIntuitiveMode: configurationSync.currentConfiguration().isIntuitiveMode
	)
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
		configurationSync.onRemoteConfigurationApplied = { [weak self] configuration in
			self?.applyRemoteConfiguration(configuration)
		}
		diceButton.setAccessibilityLabel("Roll dice")
		diceButton.setAccessibilityHint("Double tap to roll one die")
		diceView.setAccessibilityLabel("Latest die result")
		configureSceneRenderer()
		configurePowerModeObserver()
		addMenuItem(with: .more, title: "Mode", action: #selector(toggleMode))
		addMenuItem(with: .repeat, title: "Repeat", action: #selector(repeatLastRoll))
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
		configurationSync.onRemoteConfigurationApplied = nil
	}

	@IBAction func roll() {
		apply(outcome: viewModel.roll())
	}

	@objc private func toggleMode() {
		viewModel.toggleMode()
		rollCount = 0
		persistCurrentConfiguration()
		feedbackDevice.play(viewModel.isIntuitiveMode ? .directionUp : .directionDown)
		roll()
	}

	@objc private func repeatLastRoll() {
		apply(outcome: viewModel.repeatLastRoll())
	}

	private func apply(outcome: RollOutcome) {
		guard let value = outcome.values.first else {
			playInvalidInputFeedback()
			diceButton.setTitle("Invalid")
			return
		}
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
		let geometry = D6BeveledCubeGeometry.make(sideLength: sideLength)
		geometry.materials = (1...6).map { watchFaceMaterial(value: $0) }

		let node = SCNNode(geometry: geometry)
		return node
	}

	private func watchFaceMaterial(value: Int) -> SCNMaterial {
		let textureSize = CGSize(width: 256, height: 256)
		let scene = SKScene(size: textureSize)
		scene.scaleMode = .resizeFill
		scene.backgroundColor = UIColor(white: 0.96, alpha: 1.0)

		let label = SKLabelNode(text: "\(value)")
		label.fontName = "SFProDisplay-Bold"
		label.fontSize = 148
		label.fontColor = UIColor.black
		label.verticalAlignmentMode = .center
		label.horizontalAlignmentMode = .center
		label.position = CGPoint(x: textureSize.width / 2, y: textureSize.height / 2)
		scene.addChild(label)

		let material = SCNMaterial()
		material.diffuse.contents = scene
		material.locksAmbientWithDiffuse = true
		material.isDoubleSided = false
		material.roughness.contents = NSNumber(value: 0.85)
		material.metalness.contents = NSNumber(value: 0.0)
		return material
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
		switch feedbackProfile() {
		case .trueRandom:
			feedbackDevice.play(.start)
		case .intuitive:
			feedbackDevice.play(.directionUp)
		}
	}

	private func playRollSettleFeedback() {
		switch feedbackProfile() {
		case .trueRandom:
			feedbackDevice.play(.click)
		case .intuitive:
			feedbackDevice.play(.success)
		}
	}

	private func playInvalidInputFeedback() {
		feedbackDevice.play(.failure)
	}

	private func feedbackProfile() -> WatchRollFeedbackProfile {
		viewModel.isIntuitiveMode ? .intuitive : .trueRandom
	}

	private func orientation(for value: Int) -> SCNVector3 {
		let angles = D6FaceOrientation.eulerAngles(for: value)
		return SCNVector3(angles.x, angles.y, angles.z)
	}

	private func applyRemoteConfiguration(_ configuration: WatchSingleDieConfiguration) {
		guard viewModel.isIntuitiveMode != configuration.isIntuitiveMode else { return }
		viewModel.setIntuitiveMode(configuration.isIntuitiveMode)
		rollCount = 0
		roll()
	}

	private func persistCurrentConfiguration() {
		configurationSync.updateLocalConfiguration { configuration in
			configuration.isIntuitiveMode = viewModel.isIntuitiveMode
		}
	}
}
