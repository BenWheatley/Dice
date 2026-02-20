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

		let source = Self.shaderSource
		guard let library = try? device.makeLibrary(source: source, options: nil),
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

	private static let shaderSource = """
	#include <metal_stdlib>
	using namespace metal;

	struct VertexOut {
		float4 position [[position]];
		float2 uv;
	};

	struct Uniforms {
		float2 resolution;
		float time;
		uint mode;
	};

	vertex VertexOut diceBgVertex(uint vid [[vertex_id]]) {
		float2 pos[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };
		VertexOut out;
		out.position = float4(pos[vid], 0.0, 1.0);
		out.uv = (pos[vid] + 1.0) * 0.5;
		return out;
	}

	float hash21(float2 p) {
		p = fract(p * float2(123.34, 456.21));
		p += dot(p, p + 78.233);
		return fract(p.x * p.y);
	}

	float noise2(float2 p) {
		float2 i = floor(p);
		float2 f = fract(p);
		float a = hash21(i);
		float b = hash21(i + float2(1.0, 0.0));
		float c = hash21(i + float2(0.0, 1.0));
		float d = hash21(i + float2(1.0, 1.0));
		float2 u = f * f * (3.0 - 2.0 * f);
		return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
	}

	fragment float4 diceBgFragment(
		VertexOut in [[stage_in]],
		constant Uniforms& uniforms [[buffer(0)]],
		texture2d<float> stripeTexture [[texture(0)]]
	) {
		const sampler repeatSampler(filter::linear, address::repeat);
		float2 uv = in.uv;

		if (uniforms.mode == 0) {
			float fiber = noise2(float2(uv.x * uniforms.resolution.x * 0.035, uv.y * uniforms.resolution.y * 0.11));
			float streak = sin((uv.y * uniforms.resolution.y * 0.24) + (fiber * 4.0)) * 0.5 + 0.5;
			float speckle = noise2(uv * uniforms.resolution * 0.55);
			float3 base = float3(0.14, 0.36, 0.22);
			float3 color = base + (streak - 0.5) * 0.06 + (speckle - 0.5) * 0.05;
			return float4(color, 1.0);
		}

		if (uniforms.mode == 1) {
			float grainA = sin((uv.y * uniforms.resolution.y * 0.12) + noise2(float2(uv.y * 24.0, 0.0)) * 6.0);
			float grainB = sin((uv.y * uniforms.resolution.y * 0.48) + noise2(float2(uv.y * 90.0, 1.0)) * 5.0);
			float rings = grainA * 0.07 + grainB * 0.03;
			float3 base = float3(0.49, 0.31, 0.18);
			float3 color = base + float3(rings, rings * 0.7, rings * 0.4);
			return float4(color, 1.0);
		}

		float2 tiledUV = uv * float2(max(uniforms.resolution.x / 48.0, 1.0), max(uniforms.resolution.y / 48.0, 1.0));
		float3 sampled = stripeTexture.sample(repeatSampler, tiledUV).rgb;
		return float4(sampled, 1.0);
	}
	"""
}
