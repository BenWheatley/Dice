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
		isIntuitiveMode: configurationSync.currentConfiguration().isIntuitiveMode,
		sideCount: configurationSync.currentConfiguration().sideCount
	)
	private var rollCount = 0
	private var dieNode = SCNNode()
	private var activeSceneSideCount: Int?
	private let tableNode = SCNNode()
	private let tableMaterial = SCNMaterial()
	private var activeTableTexture: DiceTableTexture = .black
	private var usesSceneRenderer = false
	private var renderDecision: WatchSceneRenderDecision = .staticImage(sideCount: 6, reason: .sceneViewUnavailable)
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
		diceButton.setAccessibilityLabel(WatchAccessibilityFormatter.rollButtonLabel)
		diceButton.setAccessibilityHint(WatchAccessibilityFormatter.rollButtonHint)
		diceView.setAccessibilityLabel(WatchAccessibilityFormatter.latestResultLabel)
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
		if case let .sceneKit(sceneSideCount) = renderDecision, usesSceneRenderer {
			if DiceSingleDieSceneGeometryFactory.usesTokenGeometry(for: sceneSideCount),
				let geometry = dieNode.geometry {
				let descriptor = DiceSingleDieGeometryDescriptor(
					geometry: geometry,
					faceValueCount: sceneSideCount,
					isCoin: false,
					isToken: true
				)
				applyMaterials(to: descriptor, sideCount: sceneSideCount, currentValue: value)
			}
			animateDie(to: value, sideCount: sceneSideCount) { [weak self] in
				self?.playRollSettleFeedback()
			}
			diceSceneView.setAccessibilityValue(
				WatchAccessibilityFormatter.dieValue(value: value, sideCount: sceneSideCount)
			)
			diceView.setHidden(true)
		} else {
			applyStaticFallbackImage(value: value, sideCount: renderDecision.sideCount)
			diceView.setAccessibilityValue(
				WatchAccessibilityFormatter.dieValue(value: value, sideCount: renderDecision.sideCount)
			)
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

		let initialTexture = DiceTableTexture(rawValue: configurationSync.currentConfiguration().backgroundTexture) ?? .black
		configureTableSurface(in: scene, initialTexture: initialTexture)
		diceSceneView.setAccessibilityLabel(WatchAccessibilityFormatter.scenePreviewLabel)
		refreshRenderMode(currentValue: 1)
		applyPowerModeProfile()
	}

	private func configureTableSurface(in scene: SCNScene, initialTexture: DiceTableTexture) {
		let plane = SCNPlane(width: 24, height: 24)
		tableMaterial.lightingModel = .lambert
		tableMaterial.isLitPerPixel = true
		tableMaterial.isDoubleSided = true
		tableMaterial.diffuse.wrapS = .repeat
		tableMaterial.diffuse.wrapT = .repeat
		tableMaterial.writesToDepthBuffer = true
		tableMaterial.readsFromDepthBuffer = true
		if let tableShader = DiceShaderModifierSourceLoader.tableSurfaceShaderModifier() {
			tableMaterial.shaderModifiers = [.surface: tableShader]
		}
		plane.materials = [tableMaterial]
		tableNode.geometry = plane
		tableNode.position = SCNVector3(0, 0, -0.8)
		tableNode.castsShadow = false
		scene.rootNode.addChildNode(tableNode)
		applyTableTexture(initialTexture)
	}

	private func applyTableTexture(_ texture: DiceTableTexture) {
		activeTableTexture = texture
		tableMaterial.setValue(texture.shaderModeValue, forKey: "tableTextureMode")
		let pointSize = WKInterfaceDevice.current().screenBounds.size
		let width = max(1, pointSize.width)
		let height = max(1, pointSize.height)
		tableMaterial.setValue(max(1, min(width, height)) as NSNumber, forKey: "tableTextureScale")
		tableMaterial.setValue(width as NSNumber, forKey: "tableTextureScaleX")
		tableMaterial.setValue(height as NSNumber, forKey: "tableTextureScaleY")

		if texture == .neutral, let neutralTexture = UIImage(named: "TableNeutralTexture"), neutralTexture.size.width > 0, neutralTexture.size.height > 0 {
			tableMaterial.diffuse.contents = neutralTexture
			let repeatX = Float(width / neutralTexture.size.width)
			let repeatY = Float(height / neutralTexture.size.height)
			tableMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(repeatX, repeatY, 1)
			tableMaterial.diffuse.minificationFilter = .nearest
			tableMaterial.diffuse.magnificationFilter = .nearest
			tableMaterial.diffuse.mipFilter = .none
		} else if texture == .black {
			tableMaterial.diffuse.contents = UIColor.black
			tableMaterial.diffuse.contentsTransform = SCNMatrix4Identity
			tableMaterial.diffuse.minificationFilter = .nearest
			tableMaterial.diffuse.magnificationFilter = .nearest
			tableMaterial.diffuse.mipFilter = .none
		} else {
			tableMaterial.diffuse.contents = UIColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1.0)
			tableMaterial.diffuse.contentsTransform = SCNMatrix4Identity
			tableMaterial.diffuse.minificationFilter = .linear
			tableMaterial.diffuse.magnificationFilter = .linear
			tableMaterial.diffuse.mipFilter = .none
		}
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

	private func makeDieNode(sideCount: Int, currentValue: Int) -> SCNNode {
		let descriptor = DiceSingleDieSceneGeometryFactory.makeDescriptor(sideCount: sideCount, sideLength: 1.8)
		let node = SCNNode(geometry: descriptor.geometry)
		node.eulerAngles = DiceSingleDieSceneGeometryFactory.orientation(for: currentValue, sideCount: sideCount)
		applyMaterials(to: descriptor, sideCount: sideCount, currentValue: currentValue)
		return node
	}

	private func applyMaterials(to descriptor: DiceSingleDieGeometryDescriptor, sideCount: Int, currentValue: Int) {
		let plan = DiceSingleDieMaterialPlanner.makePlan(
			sideCount: sideCount,
			currentValue: currentValue,
			faceValueCount: descriptor.faceValueCount
		)
		let includeSideLabel = descriptor.isCoin || descriptor.isToken
		var materials: [SCNMaterial] = []
		for slot in plan.slots {
			switch slot {
			case .side:
				materials.append(solidMaterial(fillColor: UIColor(white: 0.88, alpha: 1.0)))
			case let .face(value):
				materials.append(faceMaterial(value: value, sideCount: sideCount, includeSideLabel: includeSideLabel))
			}
		}
		if plan.appliesCylindricalCapUVCompensation, materials.count >= 3 {
			DiceSingleDieMaterialPlanner.applyCylindricalCapTextureCompensation(
				top: materials[1],
				bottom: materials[2]
			)
		}
		descriptor.geometry.materials = materials
	}

	private func faceMaterial(value: Int, sideCount: Int, includeSideLabel: Bool) -> SCNMaterial {
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
		if includeSideLabel {
			let subtitle = SKLabelNode(text: "d\(sideCount)")
			subtitle.fontName = "SFProDisplay-Regular"
			subtitle.fontSize = 52
			subtitle.fontColor = UIColor.darkGray
			subtitle.verticalAlignmentMode = .center
			subtitle.horizontalAlignmentMode = .center
			subtitle.position = CGPoint(x: textureSize.width / 2, y: textureSize.height * 0.18)
			scene.addChild(subtitle)
		}

		let material = SCNMaterial()
		material.diffuse.contents = scene
		material.locksAmbientWithDiffuse = true
		material.isDoubleSided = false
		material.roughness.contents = NSNumber(value: 0.85)
		material.metalness.contents = NSNumber(value: 0.0)
		return material
	}

	private func solidMaterial(fillColor: UIColor) -> SCNMaterial {
		let material = SCNMaterial()
		material.diffuse.contents = fillColor
		material.locksAmbientWithDiffuse = true
		material.isDoubleSided = false
		material.roughness.contents = NSNumber(value: 0.85)
		material.metalness.contents = NSNumber(value: 0.0)
		return material
	}

	private func animateDie(to value: Int, sideCount: Int, completion: (() -> Void)? = nil) {
		let target = DiceSingleDieSceneGeometryFactory.orientation(for: value, sideCount: sideCount)
		SCNTransaction.begin()
		SCNTransaction.animationDuration = ProcessInfo.processInfo.isLowPowerModeEnabled ? 0.2 : 0.4
		SCNTransaction.completionBlock = completion
		dieNode.eulerAngles = target
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

	private func rebuildDieNode(sideCount: Int, currentValue: Int) {
		dieNode.removeFromParentNode()
		dieNode = makeDieNode(sideCount: sideCount, currentValue: currentValue)
		diceSceneView.scene?.rootNode.addChildNode(dieNode)
		activeSceneSideCount = sideCount
	}

	private func refreshRenderMode(currentValue: Int) {
		let decision = WatchSceneRenderFallbackPolicy.resolve(
			rawSideCount: viewModel.sideCount,
			isSceneViewReady: diceSceneView.scene != nil
		)
		renderDecision = decision
		switch decision {
		case let .sceneKit(sideCount):
			usesSceneRenderer = true
			diceSceneView.setHidden(false)
			diceView.setHidden(true)
			diceSceneView.setAccessibilityValue(
				WatchAccessibilityFormatter.dieValue(value: currentValue, sideCount: sideCount)
			)
			if activeSceneSideCount != sideCount || dieNode.parent == nil {
				rebuildDieNode(sideCount: sideCount, currentValue: currentValue)
			}
		case let .staticImage(sideCount, _):
			usesSceneRenderer = false
			diceSceneView.setHidden(true)
			diceView.setHidden(false)
			diceView.setAccessibilityValue(
				WatchAccessibilityFormatter.dieValue(value: currentValue, sideCount: sideCount)
			)
			activeSceneSideCount = nil
			applyStaticFallbackImage(value: currentValue, sideCount: sideCount)
		}
	}

	private func applyStaticFallbackImage(value: Int, sideCount: Int) {
		let clampedValue = min(max(1, value), max(1, sideCount))
		let symbolValue = min(max(1, clampedValue), 6)
		let systemName = "die.face.\(symbolValue).fill"
		if let image = UIImage(systemName: systemName) ?? UIImage(systemName: "die.face.5.fill") {
			diceView.setImage(image)
		} else {
			diceView.setImage(nil)
		}
	}

	private func applyRemoteConfiguration(_ configuration: WatchSingleDieConfiguration) {
		let remoteTexture = DiceTableTexture(rawValue: configuration.backgroundTexture) ?? .black
		if remoteTexture != activeTableTexture {
			applyTableTexture(remoteTexture)
		}
		var shouldRoll = false
		let remoteSideCount = DiceSingleDieSceneGeometryFactory.clampedSideCount(configuration.sideCount)
		if remoteSideCount != viewModel.sideCount {
			viewModel.setSideCount(remoteSideCount)
			refreshRenderMode(currentValue: 1)
			rollCount = 0
			shouldRoll = true
		}
		if viewModel.isIntuitiveMode != configuration.isIntuitiveMode {
			viewModel.setIntuitiveMode(configuration.isIntuitiveMode)
			rollCount = 0
			shouldRoll = true
		}
		if shouldRoll {
			roll()
		}
	}

	private func persistCurrentConfiguration() {
		configurationSync.updateLocalConfiguration { configuration in
			configuration.isIntuitiveMode = viewModel.isIntuitiveMode
		}
	}
}
