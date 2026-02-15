//
//  DiceCubeView.swift
//  Dice
//
//  Created by Ben Wheatley on 15.02.26.
//  Copyright © 2026 Ben Wheatley. All rights reserved.
//


import UIKit
import SceneKit

class DiceCubeView: UIView {
	private let scnView = SCNView()
	private let cubeNode = SCNNode()

	override init(frame: CGRect) {
		super.init(frame: frame)
		configureScene()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		configureScene()
	}

	private func configureScene() {
		backgroundColor = .clear
		scnView.translatesAutoresizingMaskIntoConstraints = false
		scnView.backgroundColor = .clear
		scnView.isUserInteractionEnabled = false
		scnView.antialiasingMode = .multisampling4X
		scnView.autoenablesDefaultLighting = true
		addSubview(scnView)

		NSLayoutConstraint.activate([
			scnView.leadingAnchor.constraint(equalTo: leadingAnchor),
			scnView.trailingAnchor.constraint(equalTo: trailingAnchor),
			scnView.topAnchor.constraint(equalTo: topAnchor),
			scnView.bottomAnchor.constraint(equalTo: bottomAnchor),
		])

		let scene = SCNScene()
		scnView.scene = scene

		let valuesForFaces = [1, 3, 6, 4, 2, 5] // front, right, back, left, top, bottom
		let materials = valuesForFaces.map { value -> SCNMaterial in
			let material = SCNMaterial()
			material.diffuse.contents = UIImage(named: "\(value)")
			material.locksAmbientWithDiffuse = true
			return material
		}

		let box = SCNBox(width: 1.5, height: 1.5, length: 1.5, chamferRadius: 0.09)
		box.materials = materials
		cubeNode.geometry = box
		scene.rootNode.addChildNode(cubeNode)

		let cameraNode = SCNNode()
		cameraNode.camera = SCNCamera()
		cameraNode.camera?.fieldOfView = 48
		cameraNode.position = SCNVector3(0, 0, 2.15)
		scene.rootNode.addChildNode(cameraNode)

		let keyLight = SCNNode()
		keyLight.light = SCNLight()
		keyLight.light?.type = .omni
		keyLight.light?.intensity = 900
		keyLight.position = SCNVector3(2, 2, 4)
		scene.rootNode.addChildNode(keyLight)

		let fillLight = SCNNode()
		fillLight.light = SCNLight()
		fillLight.light?.type = .ambient
		fillLight.light?.intensity = 300
		scene.rootNode.addChildNode(fillLight)
	}

	func setFaceValue(_ value: Int) {
		cubeNode.removeAllActions()
		cubeNode.eulerAngles = orientation(for: value)
	}

	func roll(to value: Int, duration: TimeInterval) {
		let target = orientation(for: value)
		cubeNode.removeAllActions()

		let adjustedDuration = max(duration, 0.9)
		let spinX = Float.random(in: Float.pi * 4 ... Float.pi * 8)
		let spinY = Float.random(in: Float.pi * 4 ... Float.pi * 8)
		let spinZ = Float.random(in: Float.pi * 2 ... Float.pi * 5)

		let mid = SCNVector3(
			cubeNode.eulerAngles.x + spinX,
			cubeNode.eulerAngles.y + spinY,
			cubeNode.eulerAngles.z + spinZ
		)
		let overshoot = SCNVector3(
			target.x + Float.random(in: -0.12...0.12),
			target.y + Float.random(in: -0.12...0.12),
			target.z + Float.random(in: -0.08...0.08)
		)

		let action1 = SCNAction.rotateTo(x: CGFloat(mid.x), y: CGFloat(mid.y), z: CGFloat(mid.z), duration: adjustedDuration * 0.78, usesShortestUnitArc: false)
		action1.timingMode = .easeIn
		let action2 = SCNAction.rotateTo(x: CGFloat(overshoot.x), y: CGFloat(overshoot.y), z: CGFloat(overshoot.z), duration: adjustedDuration * 0.14, usesShortestUnitArc: false)
		action2.timingMode = .easeOut
		let action3 = SCNAction.rotateTo(x: CGFloat(target.x), y: CGFloat(target.y), z: CGFloat(target.z), duration: adjustedDuration * 0.08, usesShortestUnitArc: false)
		action3.timingMode = .easeInEaseOut

		cubeNode.runAction(.sequence([action1, action2, action3]))
	}

	private func orientation(for value: Int) -> SCNVector3 {
		switch value {
		case 1: return SCNVector3(0, 0, 0)
		case 2: return SCNVector3(Float.pi / 2, 0, 0)
		case 3: return SCNVector3(0, -Float.pi / 2, 0)
		case 4: return SCNVector3(0, Float.pi / 2, 0)
		case 5: return SCNVector3(-Float.pi / 2, 0, 0)
		case 6: return SCNVector3(0, Float.pi, 0)
		default: return SCNVector3(0, 0, 0)
		}
	}
}
