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
	private var activeColorPreset: DiceDieColorPreset = .ivory
	private var lastRenderedValue: Int = 1
	private var usesSceneRenderer = false
	private var renderDecision: WatchSceneRenderDecision = .staticImage(sideCount: 6, reason: .sceneViewUnavailable)
	private var shouldOpenCustomizeForAutomation = false
	private var lowPowerObserver: NSObjectProtocol?
	private let feedbackDevice = WKInterfaceDevice.current()
	private let watchDieSideLength: CGFloat = 2.1
	private let watchCameraDistance: Float = 5.2
	private let watchTablePlaneSpan: CGFloat = 32
	private let watchTablePlaneZ: Float = -1.2
	private let watchRollAnimationDuration: TimeInterval = 0.42

	@IBOutlet weak var diceButton: WKInterfaceButton!
	@IBOutlet weak var diceSceneView: WKInterfaceSCNScene!

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
		let currentConfiguration = configurationSync.currentConfiguration()
		activeColorPreset = Self.colorPreset(for: currentConfiguration.colorTag)
		viewModel.setSideCount(currentConfiguration.sideCount)
		viewModel.setIntuitiveMode(currentConfiguration.isIntuitiveMode)
		configurationSync.onRemoteConfigurationApplied = { [weak self] configuration in
			self?.applyRemoteConfiguration(configuration)
		}
		shouldOpenCustomizeForAutomation = ProcessInfo.processInfo.arguments.contains("-watchOpenCustomizeOnLaunch")
		diceButton.setAccessibilityLabel(WatchAccessibilityFormatter.rollButtonLabel)
		diceButton.setAccessibilityHint(WatchAccessibilityFormatter.rollButtonHint)
		configureMenuItems()
		updateControlTitles()
		configureSceneRenderer()
		configurePowerModeObserver()
		roll()
    }

	override func willActivate() {
        super.willActivate()
		applyRemoteConfiguration(configurationSync.currentConfiguration())
		openCustomizeIfRequestedForAutomation()
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

	@IBAction func openCustomize() {
		pushController(withName: "WatchCustomizeController", context: configurationSync.currentConfiguration())
	}

	private func configureMenuItems() {
		clearAllMenuItems()
		addMenuItem(with: .more, title: "Customize", action: #selector(openCustomize))
	}

	private func openCustomizeIfRequestedForAutomation() {
		// Keep screenshot capture deterministic in simulator automation without adding production UI surface.
		guard shouldOpenCustomizeForAutomation else { return }
		shouldOpenCustomizeForAutomation = false
		DispatchQueue.main.async { [weak self] in
			self?.openCustomize()
		}
	}

	private func apply(outcome: RollOutcome) {
		guard let value = outcome.values.first else {
			playInvalidInputFeedback()
			updateControlTitles()
			return
		}
		lastRenderedValue = value
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
			let a11yValue = WatchAccessibilityFormatter.dieValue(value: value, sideCount: sceneSideCount)
			diceSceneView.setAccessibilityValue(a11yValue)
			diceButton.setAccessibilityValue(a11yValue)
		} else {
			applyStaticFallbackImage(value: value, sideCount: renderDecision.sideCount)
			let a11yValue = WatchAccessibilityFormatter.dieValue(value: value, sideCount: renderDecision.sideCount)
			diceButton.setAccessibilityValue(a11yValue)
			playRollSettleFeedback()
		}
		updateControlTitles()
	}

	private func configureSceneRenderer() {
		let scene = SCNScene()
		diceSceneView.scene = scene
		diceSceneView.antialiasingMode = .multisampling2X
		diceSceneView.preferredFramesPerSecond = 30

		let cameraNode = SCNNode()
		cameraNode.camera = SCNCamera()
		cameraNode.camera?.zNear = 0.05
		cameraNode.camera?.zFar = 120
		cameraNode.position = SCNVector3(0, 0, watchCameraDistance)
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
		let plane = SCNPlane(width: watchTablePlaneSpan, height: watchTablePlaneSpan)
		DiceTableSurfaceMaterialConfigurator.configureBaseMaterial(tableMaterial)
		plane.materials = [tableMaterial]
		tableNode.geometry = plane
		tableNode.position = SCNVector3(0, 0, watchTablePlaneZ)
		tableNode.castsShadow = false
		scene.rootNode.addChildNode(tableNode)
		applyTableTexture(initialTexture)
	}

	private func applyTableTexture(_ texture: DiceTableTexture) {
		activeTableTexture = texture
		let pointSize = WKInterfaceDevice.current().screenBounds.size
		DiceTableSurfaceMaterialConfigurator.applyTexture(
			texture,
			to: tableMaterial,
			pointScale: CGSize(width: max(1, pointSize.width), height: max(1, pointSize.height))
		)
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
		let descriptor = DiceSingleDieSceneGeometryFactory.makeDescriptor(sideCount: sideCount, sideLength: watchDieSideLength)
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
		let fillColor = activeColorPreset.fillColor
		let sideColorFactor: CGFloat = descriptor.isCoin ? 0.62 : 0.78
		var materials: [SCNMaterial] = []
		for slot in plan.slots {
			switch slot {
			case .side:
				let sideColor = DiceSingleDieMaterialFactory.multipliedColor(fillColor, factor: sideColorFactor)
				materials.append(
					DiceSingleDieMaterialFactory.makeSolidMaterial(
						baseColor: sideColor,
						fillColor: fillColor,
						dieFinish: .matte,
						dieIndex: 0
					)
				)
			case let .face(value):
				let d4VertexLabels = sideCount == 4 ? DiceSingleDieSceneGeometryFactory.d4VertexLabels(forFaceValue: value) : []
				materials.append(
					DiceSingleDieMaterialFactory.makeFaceMaterial(
						value: value,
						sideCount: sideCount,
						fillColor: fillColor,
						numeralFont: .classic,
						pipStyle: .round,
						largeFaceLabelsEnabled: false,
						d4VertexLabels: d4VertexLabels,
						dieFinish: .matte,
						dieIndex: 0
					)
				)
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

	private func animateDie(to value: Int, sideCount: Int, completion: (() -> Void)? = nil) {
		let target = DiceSingleDieSceneGeometryFactory.orientation(for: value, sideCount: sideCount)
		dieNode.removeAllActions()
		let duration = ProcessInfo.processInfo.isLowPowerModeEnabled ? max(0.24, watchRollAnimationDuration * 0.65) : watchRollAnimationDuration
		if DiceSingleDieSceneGeometryFactory.usesCoinGeometry(for: sideCount) || DiceSingleDieSceneGeometryFactory.usesTokenGeometry(for: sideCount) {
			let spinDirection: Float = Bool.random() ? 1 : -1
			let action = SCNAction.customAction(duration: duration) { node, elapsed in
				let progress = Float(elapsed / CGFloat(duration))
				node.eulerAngles = DiceRollAnimationMath.cylindricalEulerAngles(
					targetOrientation: target,
					progress: progress,
					motionScale: 1,
					spinDirection: spinDirection
				)
			}
			dieNode.runAction(action) { completion?() }
			return
		}

		let start = dieNode.presentation.eulerAngles
		let spinTarget = SCNVector3(
			target.x + DiceRollAnimationMath.randomTurnRadians(min: 2, max: 4),
			target.y + DiceRollAnimationMath.randomTurnRadians(min: 2, max: 4),
			target.z + DiceRollAnimationMath.randomTurnRadians(min: 1, max: 3)
		)
		let rotateAction = SCNAction.customAction(duration: duration) { node, elapsed in
			let progress = Float(elapsed / CGFloat(duration))
			let eased = DiceRollAnimationMath.settleProgress(progress)
			node.eulerAngles = SCNVector3(
				start.x + (spinTarget.x - start.x) * eased,
				start.y + (spinTarget.y - start.y) * eased,
				start.z + (spinTarget.z - start.z) * eased
			)
		}
		dieNode.runAction(rotateAction) { completion?() }
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
		lastRenderedValue = currentValue
		let decision = WatchSceneRenderFallbackPolicy.resolve(
			rawSideCount: viewModel.sideCount,
			isSceneViewReady: diceSceneView.scene != nil
		)
		renderDecision = decision
		switch decision {
		case let .sceneKit(sideCount):
			usesSceneRenderer = true
			diceSceneView.setHidden(false)
			diceButton.setBackgroundImage(nil)
			diceSceneView.setAccessibilityValue(
				WatchAccessibilityFormatter.dieValue(value: currentValue, sideCount: sideCount)
			)
			if activeSceneSideCount != sideCount || dieNode.parent == nil {
				rebuildDieNode(sideCount: sideCount, currentValue: currentValue)
			}
		case let .staticImage(sideCount, _):
			usesSceneRenderer = false
			diceSceneView.setHidden(true)
			activeSceneSideCount = nil
			applyStaticFallbackImage(value: currentValue, sideCount: sideCount)
		}
	}

	private func applyStaticFallbackImage(value: Int, sideCount: Int) {
		let clampedValue = min(max(1, value), max(1, sideCount))
		let symbolValue = min(max(1, clampedValue), 6)
		let systemName = "die.face.\(symbolValue).fill"
		if let image = UIImage(systemName: systemName) ?? UIImage(systemName: "die.face.5.fill") {
			diceButton.setBackgroundImage(image)
		} else {
			diceButton.setBackgroundImage(nil)
		}
	}

	private func applyRemoteConfiguration(_ configuration: WatchSingleDieConfiguration) {
		let remoteTexture = DiceTableTexture(rawValue: configuration.backgroundTexture) ?? .black
		if remoteTexture != activeTableTexture {
			applyTableTexture(remoteTexture)
		}
		let remotePreset = Self.colorPreset(for: configuration.colorTag)
		if remotePreset != activeColorPreset {
			activeColorPreset = remotePreset
			refreshCurrentDieAppearance()
		}
		var shouldRoll = false
		let remoteSideCount = DiceSingleDieSceneGeometryFactory.clampedSideCount(configuration.sideCount)
		if remoteSideCount != viewModel.sideCount {
			viewModel.setSideCount(remoteSideCount)
			refreshRenderMode(currentValue: lastRenderedValue)
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
		} else {
			updateControlTitles()
		}
	}

	private func refreshCurrentDieAppearance() {
		guard case let .sceneKit(sideCount) = renderDecision,
			  usesSceneRenderer,
			  let geometry = dieNode.geometry else { return }
		let descriptor = DiceSingleDieGeometryDescriptor(
			geometry: geometry,
			faceValueCount: sideCount,
			isCoin: DiceSingleDieSceneGeometryFactory.usesCoinGeometry(for: sideCount),
			isToken: DiceSingleDieSceneGeometryFactory.usesTokenGeometry(for: sideCount)
		)
		applyMaterials(to: descriptor, sideCount: sideCount, currentValue: lastRenderedValue)
	}

	private static func colorPreset(for colorTag: String) -> DiceDieColorPreset {
		DiceDieColorPreset.fromNotation(colorTag) ?? .ivory
	}

	private func updateControlTitles() {
		diceButton.setTitle(nil)
	}
}
