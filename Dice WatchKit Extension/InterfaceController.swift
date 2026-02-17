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

	@IBOutlet weak var diceButton: WKInterfaceButton!
	@IBOutlet weak var diceView: WKInterfaceImage!
	@IBOutlet weak var diceSceneView: WKInterfaceSCNScene!

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
		diceButton.setAccessibilityLabel("Roll dice")
		diceButton.setAccessibilityHint("Double tap to roll one die")
		diceView.setAccessibilityLabel("Latest die result")
		configureSceneRenderer()
		addMenuItem(with: .more, title: "Mode", action: #selector(toggleMode))
		roll()
    }

	override func willActivate() {
        super.willActivate()
    }

    override func didDeactivate() {
        super.didDeactivate()
    }

	@IBAction func roll() {
		let outcome = viewModel.roll()
		guard let value = outcome.values.first else { return }
		rollCount += 1
		if usesSceneRenderer {
			animateD6(to: value)
			diceSceneView.setAccessibilityValue("Value \(value)")
			diceView.setHidden(true)
		} else {
			diceView.setImageNamed("\(value)")
			diceView.setAccessibilityValue("Value \(value)")
			diceView.setHidden(false)
		}
		diceButton.setTitle(viewModel.statusText(rollCount: rollCount))
		WKInterfaceDevice.current().play(.click)
	}

	@objc private func toggleMode() {
		viewModel.toggleMode()
		rollCount = 0
		WKInterfaceDevice.current().play(.success)
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
	}

	private func makeD6Node() -> SCNNode {
		let sideLength: CGFloat = 1.8
		let geometry = SCNBox(
			width: sideLength,
			height: sideLength,
			length: sideLength,
			chamferRadius: sideLength * 0.08
		)
		geometry.chamferSegmentCount = 4
		geometry.materials = (1...6).map { faceMaterial(value: $0) }

		let node = SCNNode(geometry: geometry)
		return node
	}

	private func faceMaterial(value: Int) -> SCNMaterial {
		let material = SCNMaterial()
		material.diffuse.contents = d6FaceTexture(value: value)
		material.locksAmbientWithDiffuse = true
		material.isDoubleSided = false
		return material
	}

	private func d6FaceTexture(value: Int) -> UIImage {
		let size = CGSize(width: 256, height: 256)
		let width = Int(size.width)
		let height = Int(size.height)
		guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
			  let context = CGContext(
				data: nil,
				width: width,
				height: height,
				bitsPerComponent: 8,
				bytesPerRow: 0,
				space: colorSpace,
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
			  ) else {
			return UIImage()
		}

		let rect = CGRect(origin: .zero, size: size)
		context.setFillColor(CGColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0))
		context.fill(rect)
		context.setStrokeColor(CGColor(red: 0.70, green: 0.70, blue: 0.70, alpha: 1.0))
		context.setLineWidth(8)
		context.stroke(rect.insetBy(dx: 6, dy: 6))

		let pipPositions: [CGPoint] = [
			CGPoint(x: size.width * 0.28, y: size.height * 0.28),
			CGPoint(x: size.width * 0.50, y: size.height * 0.28),
			CGPoint(x: size.width * 0.72, y: size.height * 0.28),
			CGPoint(x: size.width * 0.28, y: size.height * 0.50),
			CGPoint(x: size.width * 0.50, y: size.height * 0.50),
			CGPoint(x: size.width * 0.72, y: size.height * 0.50),
			CGPoint(x: size.width * 0.28, y: size.height * 0.72),
			CGPoint(x: size.width * 0.50, y: size.height * 0.72),
			CGPoint(x: size.width * 0.72, y: size.height * 0.72),
		]

		let indexesByValue: [Int: [Int]] = [
			1: [4],
			2: [0, 8],
			3: [0, 4, 8],
			4: [0, 2, 6, 8],
			5: [0, 2, 4, 6, 8],
			6: [0, 2, 3, 5, 6, 8],
		]

		let radius = size.width * 0.08
		context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1.0))
		for index in indexesByValue[value] ?? [] {
			let center = pipPositions[index]
			let pipRect = CGRect(
				x: center.x - radius,
				y: center.y - radius,
				width: radius * 2,
				height: radius * 2
			)
			context.fillEllipse(in: pipRect)
		}

		guard let image = context.makeImage() else { return UIImage() }
		return UIImage(cgImage: image)
	}

	private func animateD6(to value: Int) {
		let target = orientation(for: value)
		SCNTransaction.begin()
		SCNTransaction.animationDuration = 0.4
		d6Node.eulerAngles = target
		SCNTransaction.commit()
	}

	private func orientation(for value: Int) -> SCNVector3 {
		switch value {
		case 1:
			return SCNVector3Zero
		case 2:
			return SCNVector3(0, -Float.pi / 2, 0)
		case 3:
			return SCNVector3(0, Float.pi, 0)
		case 4:
			return SCNVector3(0, Float.pi / 2, 0)
		case 5:
			return SCNVector3(Float.pi / 2, 0, 0)
		case 6:
			return SCNVector3(-Float.pi / 2, 0, 0)
		default:
			return SCNVector3Zero
		}
	}
}
