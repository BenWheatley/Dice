//
//  DiceCubeView.swift
//  Dice
//
//  Created by Ben Wheatley on 15.02.26.
//  Copyright © 2026 Ben Wheatley. All rights reserved.
//

import UIKit
import SceneKit

final class DiceCubeView: UIView {
	private let scnView = SCNView()
	private let scene = SCNScene()
	private let cameraNode = SCNNode()
	private var cubeNodes: [SCNNode] = []
	private var cubeValues: [Int] = []
	private var currentSideLength: CGFloat = 0

	override init(frame: CGRect) {
		super.init(frame: frame)
		configureScene()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		configureScene()
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		updateCamera()
	}

	func setDice(values: [Int], centers: [CGPoint], sideLength: CGFloat, animated: Bool) {
		guard values.count == centers.count else { return }
		ensureNodeCount(values.count)

		if abs(currentSideLength - sideLength) > 0.5 {
			currentSideLength = sideLength
			for node in cubeNodes {
				node.geometry = makeGeometry(sideLength: sideLength)
			}
		}

		for index in values.indices {
			let node = cubeNodes[index]
			let targetPosition = scenePosition(for: centers[index])
			let targetFace = values[index]
			let startPosition = SCNVector3(node.presentation.position.x, node.presentation.position.y, 0)

			if animated {
				animateRoll(node: node, from: startPosition, to: targetPosition, faceValue: targetFace, sideLength: sideLength)
			} else {
				node.removeAllActions()
				node.position = targetPosition
				node.eulerAngles = orientation(for: targetFace)
			}
		}

		cubeValues = values
	}

	private func configureScene() {
		backgroundColor = .clear
		isUserInteractionEnabled = false

		scnView.translatesAutoresizingMaskIntoConstraints = false
		scnView.backgroundColor = .clear
		scnView.isUserInteractionEnabled = false
		scnView.antialiasingMode = .multisampling4X
		scnView.autoenablesDefaultLighting = true
		scnView.scene = scene
		addSubview(scnView)

		NSLayoutConstraint.activate([
			scnView.leadingAnchor.constraint(equalTo: leadingAnchor),
			scnView.trailingAnchor.constraint(equalTo: trailingAnchor),
			scnView.topAnchor.constraint(equalTo: topAnchor),
			scnView.bottomAnchor.constraint(equalTo: bottomAnchor),
		])

		cameraNode.camera = SCNCamera()
		cameraNode.camera?.usesOrthographicProjection = true
		cameraNode.camera?.zNear = 1
		cameraNode.camera?.zFar = 10000
		cameraNode.position = SCNVector3(0, 0, 800)
		scene.rootNode.addChildNode(cameraNode)

		let keyLight = SCNNode()
		keyLight.light = SCNLight()
		keyLight.light?.type = .omni
		keyLight.light?.intensity = 900
		keyLight.position = SCNVector3(160, 220, 280)
		scene.rootNode.addChildNode(keyLight)

		let fillLight = SCNNode()
		fillLight.light = SCNLight()
		fillLight.light?.type = .ambient
		fillLight.light?.intensity = 350
		scene.rootNode.addChildNode(fillLight)
	}

	private func updateCamera() {
		cameraNode.camera?.orthographicScale = Double(bounds.height / 2)
	}

	private func ensureNodeCount(_ count: Int) {
		if cubeNodes.count > count {
			for node in cubeNodes[count...] {
				node.removeFromParentNode()
			}
			cubeNodes = Array(cubeNodes.prefix(count))
		}

		while cubeNodes.count < count {
			let node = SCNNode()
			node.geometry = makeGeometry(sideLength: max(currentSideLength, 60))
			scene.rootNode.addChildNode(node)
			cubeNodes.append(node)
		}
	}

	private func makeGeometry(sideLength: CGFloat) -> SCNGeometry {
		let valuesForFaces = [1, 3, 6, 4, 2, 5] // front, right, back, left, top, bottom
		let materials = valuesForFaces.map { value -> SCNMaterial in
			let material = SCNMaterial()
			material.diffuse.contents = zoomedTexture(named: "\(value)", factor: 1.25)
			material.locksAmbientWithDiffuse = true
			return material
		}

		let box = SCNBox(
			width: sideLength,
			height: sideLength,
			length: sideLength,
			chamferRadius: sideLength * 0.06
		)
		box.materials = materials
		return box
	}

	private func scenePosition(for center: CGPoint) -> SCNVector3 {
		SCNVector3(
			center.x - bounds.midX,
			bounds.midY - center.y,
			0
		)
	}

	private func animateRoll(node: SCNNode, from start: SCNVector3, to target: SCNVector3, faceValue: Int, sideLength: CGFloat) {
		node.removeAllActions()

		let duration: TimeInterval = 1.6
		let moveAction = makeBounceMoveAction(start: start, target: target, sideLength: sideLength, duration: duration)
		let rotateAction = makeRotateAction(node: node, targetFace: faceValue, duration: duration)
		let settle = SCNAction.run { n in
			n.position = target
			n.eulerAngles = self.orientation(for: faceValue)
		}

		node.runAction(.sequence([.group([moveAction, rotateAction]), settle]))
	}

	private func makeRotateAction(node: SCNNode, targetFace: Int, duration: TimeInterval) -> SCNAction {
		let target = orientation(for: targetFace)
		let current = node.presentation.eulerAngles
		let peakTime = duration * 0.16
		let decayWindow = max(0.001, duration - peakTime)
		let rampSharpness = 5.0
		let decaySharpness = 6.0

		let spinTarget = SCNVector3(
			target.x + Float.random(in: Float.pi * 4 ... Float.pi * 8),
			target.y + Float.random(in: Float.pi * 4 ... Float.pi * 8),
			target.z + Float.random(in: Float.pi * 2 ... Float.pi * 5)
		)

		// Normalize integrated angular velocity so progress reaches exactly 1 at t=duration.
		let eRamp = exp(-rampSharpness)
		let rampIntegralAtPeak = peakTime * (1.0 / (1.0 - eRamp) - 1.0 / rampSharpness)
		let decayIntegralFull = decayWindow * (1.0 - exp(-decaySharpness)) / decaySharpness
		let omegaMax = 1.0 / max(0.0001, rampIntegralAtPeak + decayIntegralFull)

		return SCNAction.customAction(duration: duration) { n, elapsed in
			let t = TimeInterval(elapsed)
			let progress: Double
			if t <= peakTime {
				// Fast ramp-up of angular velocity.
				let scaled = t / peakTime
				let expTerm = exp(-rampSharpness * scaled)
				let rampIntegral = (t / (1.0 - eRamp)) + (peakTime / rampSharpness) * (expTerm - 1.0) / (1.0 - eRamp)
				progress = max(0, min(1, omegaMax * rampIntegral))
			} else {
				// Exponential decay of angular velocity after peak.
				let x = t - peakTime
				let decayIntegral = decayWindow * (1.0 - exp(-decaySharpness * (x / decayWindow))) / decaySharpness
				progress = max(0, min(1, omegaMax * (rampIntegralAtPeak + decayIntegral)))
			}

			let p = Float(progress)
			let x = current.x + (spinTarget.x - current.x) * p
			let y = current.y + (spinTarget.y - current.y) * p
			let z = current.z + (spinTarget.z - current.z) * p
			n.eulerAngles = SCNVector3(x, y, z)
		}
	}

	private func zoomedTexture(named name: String, factor: CGFloat) -> UIImage? {
		guard let source = UIImage(named: name) else { return nil }
		let size = source.size
		let renderer = UIGraphicsImageRenderer(size: size)
		let zoomed = renderer.image { _ in
			let w = size.width * factor
			let h = size.height * factor
			let rect = CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
			source.draw(in: rect)
		}
		return zoomed
	}

	private func makeBounceMoveAction(start: SCNVector3, target: SCNVector3, sideLength: CGFloat, duration: TimeInterval) -> SCNAction {
		let halfW = Float(bounds.width / 2)
		let halfH = Float(bounds.height / 2)
		let margin = Float(sideLength / 2 + 6)
		let minX = -halfW + margin
		let maxX = halfW - margin
		let minY = -halfH + margin
		let maxY = halfH - margin

		var lastTime: TimeInterval = 0
		var pos = start
		var vel = SCNVector3(
			Float.random(in: -420...420),
			Float.random(in: -330...330),
			0
		)

		return SCNAction.customAction(duration: duration) { node, elapsed in
			let t = TimeInterval(elapsed)
			let dt = max(0.0, t - lastTime)
			lastTime = t
			if dt <= 0 { return }

			pos.x += vel.x * Float(dt)
			pos.y += vel.y * Float(dt)

			if pos.x < minX {
				pos.x = minX
				vel.x = -vel.x * 0.84
			} else if pos.x > maxX {
				pos.x = maxX
				vel.x = -vel.x * 0.84
			}

			if pos.y < minY {
				pos.y = minY
				vel.y = -vel.y * 0.84
			} else if pos.y > maxY {
				pos.y = maxY
				vel.y = -vel.y * 0.84
			}

			let damping = powf(0.988, Float(dt * 60))
			vel.x *= damping
			vel.y *= damping

			let progress = min(1, Float(t / duration))
			let blend = powf(progress, 3.0)
			let x = pos.x * (1 - blend) + target.x * blend
			let y = pos.y * (1 - blend) + target.y * blend
			node.position = SCNVector3(x, y, 0)
		}
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
