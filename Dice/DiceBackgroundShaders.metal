#include <metal_stdlib>
using namespace metal;

struct DiceBgVertexOut {
	float4 position [[position]];
	float2 uv;
};

struct DiceBgUniforms {
	float2 resolution;
	float time;
	uint mode;
};

vertex DiceBgVertexOut diceBgVertex(uint vid [[vertex_id]]) {
	float2 pos[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };
	DiceBgVertexOut out;
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
	DiceBgVertexOut in [[stage_in]],
	constant DiceBgUniforms& uniforms [[buffer(0)]],
	texture2d<float> stripeTexture [[texture(0)]]
) {
	const sampler repeatSampler(filter::linear, address::repeat);
	float2 uv = in.uv;

	if (uniforms.mode == 0) {
		float fiberA = noise2(float2(uv.x * uniforms.resolution.x * 0.012, uv.y * uniforms.resolution.y * 0.050));
		float fiberB = noise2(float2((uv.x + 0.27) * uniforms.resolution.x * 0.018, (uv.y + 0.13) * uniforms.resolution.y * 0.032));
		float streak = sin((uv.y * uniforms.resolution.y * 0.10) + (fiberA * 2.2) + (fiberB * 1.1)) * 0.5 + 0.5;
		float speckle = noise2(uv * uniforms.resolution * 0.22);
		float lint = noise2((uv + float2(0.31, 0.07)) * uniforms.resolution * 0.08);
		float3 base = float3(0.13, 0.35, 0.21);
		float3 color = base + (streak - 0.5) * 0.045 + (speckle - 0.5) * 0.020 + (lint - 0.5) * 0.015;
		return float4(color, 1.0);
	}

	if (uniforms.mode == 1) {
		float grainA = sin((uv.y * uniforms.resolution.y * 0.28) + noise2(float2(uv.y * 58.0, 0.0)) * 5.0);
		float grainB = sin((uv.y * uniforms.resolution.y * 1.05) + noise2(float2(uv.y * 180.0, 1.0)) * 4.5);
		float fine = noise2(float2(uv.x * uniforms.resolution.x * 0.22, uv.y * uniforms.resolution.y * 0.9));
		float pore = smoothstep(0.84, 0.98, noise2(float2(uv.x * uniforms.resolution.x * 0.90, uv.y * uniforms.resolution.y * 2.8)));
		float rings = grainA * 0.05 + grainB * 0.02 + (fine - 0.5) * 0.01 - pore * 0.04;
		float3 base = float3(0.49, 0.31, 0.18);
		float3 color = base + float3(rings, rings * 0.7, rings * 0.4);
		return float4(color, 1.0);
	}

	float2 tiledUV = uv * float2(max(uniforms.resolution.x / 24.0, 1.0), max(uniforms.resolution.y / 24.0, 1.0));
	float3 sampled = stripeTexture.sample(repeatSampler, tiledUV).rgb;
	return float4(sampled, 1.0);
}
