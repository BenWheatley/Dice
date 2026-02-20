import Foundation
import QuartzCore
import MetalKit

final class DiceMetalTextureRenderer: NSObject, MTKViewDelegate {
	private struct Uniforms {
		var resolution: SIMD2<Float>
		var time: Float
		var mode: UInt32
	}

	private let device: MTLDevice
	private let commandQueue: MTLCommandQueue
	private let pipelineState: MTLRenderPipelineState
	private let startTime = CACurrentMediaTime()
	private var mode: UInt32
	private var stripeTexture: MTLTexture?

	init?(device: MTLDevice, texture: DiceTableTexture) {
		self.device = device
		guard let commandQueue = device.makeCommandQueue() else { return nil }
		self.commandQueue = commandQueue
		self.mode = Self.modeValue(for: texture)

		let library: MTLLibrary
		do {
			library = try device.makeDefaultLibrary(bundle: .main)
		} catch {
			guard let fallbackLibrary = device.makeDefaultLibrary() else { return nil }
			library = fallbackLibrary
		}
		guard
			  let vertex = library.makeFunction(name: "diceBgVertex"),
			  let fragment = library.makeFunction(name: "diceBgFragment") else {
			return nil
		}

		let descriptor = MTLRenderPipelineDescriptor()
		descriptor.vertexFunction = vertex
		descriptor.fragmentFunction = fragment
		descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
		guard let pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor) else {
			return nil
		}
		self.pipelineState = pipelineState
		super.init()
		self.stripeTexture = Self.loadStripeTexture(device: device)
	}

	func setTexture(_ texture: DiceTableTexture) {
		mode = Self.modeValue(for: texture)
	}

	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

	func draw(in view: MTKView) {
		guard let descriptor = view.currentRenderPassDescriptor,
			  let drawable = view.currentDrawable,
			  let commandBuffer = commandQueue.makeCommandBuffer(),
			  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
			return
		}

		let uniforms = Uniforms(
			resolution: SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height)),
			time: Float(CACurrentMediaTime() - startTime),
			mode: mode
		)
		encoder.setRenderPipelineState(pipelineState)
		encoder.setFragmentBytes([uniforms], length: MemoryLayout<Uniforms>.stride, index: 0)
		if let stripeTexture {
			encoder.setFragmentTexture(stripeTexture, index: 0)
		}
		encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
		encoder.endEncoding()

		commandBuffer.present(drawable)
		commandBuffer.commit()
	}

	private static func modeValue(for texture: DiceTableTexture) -> UInt32 {
		switch texture {
		case .felt:
			return 0
		case .wood:
			return 1
		case .neutral:
			return 2
		}
	}

	private static func loadStripeTexture(device: MTLDevice) -> MTLTexture? {
		guard let image = UIImage(named: "stripes"), let cgImage = image.cgImage else { return nil }
		let loader = MTKTextureLoader(device: device)
		return try? loader.newTexture(
			cgImage: cgImage,
			options: [
				MTKTextureLoader.Option.SRGB: false,
				MTKTextureLoader.Option.origin: MTKTextureLoader.Origin.topLeft
			]
		)
	}
}
