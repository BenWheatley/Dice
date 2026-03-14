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
	private let watchDieSideLength: CGFloat = 3.4
	private let watchRollAnimationDuration: TimeInterval = 0.42

	@IBOutlet weak var diceButton: WKInterfaceButton!
	@IBOutlet weak var statusLabel: WKInterfaceLabel!
	@IBOutlet weak var diceSceneView: WKInterfaceSCNScene!
	@IBOutlet weak var optionsButton: WKInterfaceButton!

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
		statusLabel.setAccessibilityLabel("Roll status")
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
			statusLabel.setText("Invalid roll")
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
		statusLabel.setText(viewModel.statusText(lastValue: value))
	}

	private func configureSceneRenderer() {
		let scene = SCNScene()
		diceSceneView.scene = scene
		diceSceneView.antialiasingMode = .multisampling2X
		diceSceneView.preferredFramesPerSecond = 30

		let cameraNode = SCNNode()
		cameraNode.camera = SCNCamera()
		cameraNode.position = SCNVector3(0, 0, 3.2)
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
		DiceTableSurfaceMaterialConfigurator.configureBaseMaterial(tableMaterial)
		plane.materials = [tableMaterial]
		tableNode.geometry = plane
		tableNode.position = SCNVector3(0, 0, -0.8)
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
		let style = DiceFaceContrast.style(for: activeColorPreset.fillColor)
		let includeSideLabel = descriptor.isCoin || descriptor.isToken
		var materials: [SCNMaterial] = []
		for slot in plan.slots {
			switch slot {
			case .side:
				materials.append(solidMaterial(fillColor: style.borderColor))
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
		let fillColor = activeColorPreset.fillColor
		let d4VertexLabels = sideCount == 4 ? DiceSingleDieSceneGeometryFactory.d4VertexLabels(forFaceValue: value) : []
		let textureSet = DiceFaceTextureFactory.textureSet(
			value: value,
			sideCount: sideCount,
			fillColor: fillColor,
			numeralFont: .classic,
			pipStyle: .round,
			largeFaceLabelsEnabled: false,
			d4VertexLabels: d4VertexLabels
		)

		let material = SCNMaterial()
		material.diffuse.contents = textureSet.diffuse
		material.normal.contents = textureSet.normal
		material.normal.intensity = 0.95
		material.specular.contents = textureSet.metalness
		material.metalness.contents = textureSet.metalness
		material.roughness.contents = textureSet.roughness
		material.locksAmbientWithDiffuse = true
		material.isDoubleSided = false
		if includeSideLabel {
			material.diffuse.contentsTransform = SCNMatrix4Identity
		}
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
		dieNode.removeAllActions()
		let duration = ProcessInfo.processInfo.isLowPowerModeEnabled ? max(0.24, watchRollAnimationDuration * 0.65) : watchRollAnimationDuration
		if DiceSingleDieSceneGeometryFactory.usesCoinGeometry(for: sideCount) || DiceSingleDieSceneGeometryFactory.usesTokenGeometry(for: sideCount) {
			let spinDirection: Float = Bool.random() ? 1 : -1
			let action = SCNAction.customAction(duration: duration) { [weak self] node, elapsed in
				guard let self else { return }
				let progress = Float(max(0, min(1, elapsed / CGFloat(duration))))
				node.eulerAngles = self.cylindricalAnimationEulerAngles(
					sideCount: sideCount,
					targetValue: value,
					progress: progress,
					spinDirection: spinDirection
				)
			}
			dieNode.runAction(action) { completion?() }
			return
		}

		let start = dieNode.presentation.eulerAngles
		let spinTarget = SCNVector3(
			target.x + randomTurnRadians(min: 2, max: 4),
			target.y + randomTurnRadians(min: 2, max: 4),
			target.z + randomTurnRadians(min: 1, max: 3)
		)
		let rotateAction = SCNAction.customAction(duration: duration) { node, elapsed in
			let progress = Float(max(0, min(1, elapsed / CGFloat(duration))))
			let eased = 1 - powf(1 - progress, 3)
			node.eulerAngles = SCNVector3(
				start.x + (spinTarget.x - start.x) * eased,
				start.y + (spinTarget.y - start.y) * eased,
				start.z + (spinTarget.z - start.z) * eased
			)
		}
		dieNode.runAction(rotateAction) { completion?() }
	}

	private func randomTurnRadians(min: Int, max: Int) -> Float {
		let turns = Float(Int.random(in: min...max))
		let sign: Float = Bool.random() ? 1 : -1
		return turns * sign * Float.pi * 2
	}

	private func pinnedRollSettleProgress(_ progress: Float) -> Float {
		let clamped = max(0, min(1, progress))
		return 1 - powf(1 - clamped, 3)
	}

	private func cylindricalAnimationEulerAngles(
		sideCount: Int,
		targetValue: Int,
		progress: Float,
		spinDirection: Float
	) -> SCNVector3 {
		let clamped = max(0, min(1, progress))
		let target = DiceSingleDieSceneGeometryFactory.orientation(for: targetValue, sideCount: sideCount)
		let turns: Float = 3
		let spinMagnitude = turns * spinDirection * Float.pi * 2
		let tiltProgress = pinnedRollSettleProgress(clamped)
		let residualSpin = pow(1 - clamped, 3)
		return SCNVector3(
			target.x * tiltProgress,
			target.y * tiltProgress,
			target.z + (spinMagnitude * residualSpin)
		)
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
			statusLabel.setText(viewModel.statusText(lastValue: lastRenderedValue))
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
		optionsButton.setTitle("Customize")
	}
}
