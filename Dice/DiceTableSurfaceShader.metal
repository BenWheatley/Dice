#pragma arguments
float tableTextureMode;
float tableTextureScale;
float tableTextureScaleX;
float tableTextureScaleY;

#pragma declaration
float tableHash21(float2 p) {
	p = fract(p * float2(123.34, 456.21));
	p += dot(p, p + 78.233);
	return fract(p.x * p.y);
}

float tableNoise2(float2 p) {
	float2 i = floor(p);
	float2 f = fract(p);
	float a = tableHash21(i);
	float b = tableHash21(i + float2(1.0, 0.0));
	float c = tableHash21(i + float2(0.0, 1.0));
	float d = tableHash21(i + float2(1.0, 1.0));
	float2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

#pragma body
// Base UV center.
float2 centeredUV = (_surface.diffuseTexcoord - 0.5);
// Legacy scalar space used by felt/wood paths to preserve their tuned frequency.
float2 p = centeredUV * max(tableTextureScale, 1.0);

float3 color;
if (tableTextureMode < 0.5) {
	// Felt: low-amplitude fibers + lint.
	float fiberA = tableNoise2(float2(p.x * 0.020, p.y * 0.080));
	float fiberB = tableNoise2(float2(p.x * 0.034 + 17.0, p.y * 0.052 + 9.0));
	float streak = sin((p.y * 0.34) + (fiberA * 2.3) + (fiberB * 1.3)) * 0.5 + 0.5;
	float speckle = tableNoise2(p * 0.18 + float2(4.0, 11.0));
	float lint = tableNoise2(p * 0.08 + float2(29.0, 7.0));
	float3 base = float3(0.13, 0.35, 0.21);
	color = base + (streak - 0.5) * 0.045 + (speckle - 0.5) * 0.022 + (lint - 0.5) * 0.016;
	_surface.roughness = 0.98;
} else if (tableTextureMode < 1.5) {
	// Wood: broad warped grain bands with fine pores.
	float boundaryWarp = (tableNoise2(float2(p.x * 0.026, p.y * 0.050)) - 0.5) * 12.0;
	boundaryWarp += (tableNoise2(float2(p.x * 0.082 + 13.0, p.y * 0.120 + 3.0)) - 0.5) * 4.5;
	float warped = p.y * 0.19 + boundaryWarp;
	float grainA = sin(warped * 0.35 + tableNoise2(float2(warped * 0.040, 0.0)) * 5.0);
	float grainB = sin(warped * 1.10 + tableNoise2(float2(warped * 0.10, 1.0)) * 4.2);
	float fine = tableNoise2(float2(p.x * 0.23, p.y * 0.95));
	float pore = smoothstep(0.84, 0.98, tableNoise2(float2(p.x * 0.85, p.y * 2.6)));
	float rings = grainA * 0.05 + grainB * 0.02 + (fine - 0.5) * 0.012 - pore * 0.04;
	float3 base = float3(0.49, 0.31, 0.18);
	color = base + float3(rings, rings * 0.72, rings * 0.42);
	_surface.roughness = 0.92;
} else {
	// Neutral: texture-backed stripes. Host code configures diffuse.contentsTransform so
	// one source texture pixel maps to one screen point in neutral mode.
	color = _surface.diffuse.rgb;
	_surface.roughness = 0.95;
}

_surface.diffuse.rgb = clamp(color, 0.0, 1.0);
_surface.metalness = 0.0;
_surface.specular.rgb = float3(0.0);
