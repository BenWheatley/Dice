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
// Procedural felt/wood patterns use per-axis point mapping so texture scale stays stable
// when the view rotates between portrait and landscape.
float2 p = centeredUV * float2(max(tableTextureScaleX, 1.0), max(tableTextureScaleY, 1.0));

float3 color;
if (tableTextureMode < 0.5) {
	// Felt: layered directional fibers plus speckled lint at point-mapped frequency.
	float fiberA = tableNoise2(float2(p.x * 0.060, p.y * 0.145));
	float fiberB = tableNoise2(float2(p.x * 0.115 + 17.0, p.y * 0.090 + 9.0));
	float streak = sin((p.y * 0.58) + (fiberA * 2.7) + (fiberB * 1.8)) * 0.5 + 0.5;
	float speckle = tableNoise2(p * 0.36 + float2(4.0, 11.0));
	float lint = tableNoise2(p * 0.19 + float2(29.0, 7.0));
	float3 base = float3(0.13, 0.35, 0.21);
	color = base + (streak - 0.5) * 0.050 + (speckle - 0.5) * 0.024 + (lint - 0.5) * 0.018;
	_surface.roughness = 0.98;
} else if (tableTextureMode < 1.5) {
	// Wood: broad curved grain with medium-detail pores; tuned for visible texture at v1 zoom.
	float boundaryWarp = (tableNoise2(float2(p.x * 0.020, p.y * 0.042)) - 0.5) * 11.0;
	boundaryWarp += (tableNoise2(float2(p.x * 0.067 + 13.0, p.y * 0.102 + 3.0)) - 0.5) * 5.2;
	float warped = p.y * 0.145 + boundaryWarp;
	float grainA = sin(warped * 0.46 + tableNoise2(float2(warped * 0.045, 0.0)) * 5.4);
	float grainB = sin(warped * 1.38 + tableNoise2(float2(warped * 0.13, 1.0)) * 4.6);
	float fine = tableNoise2(float2(p.x * 0.34, p.y * 1.28));
	float pore = smoothstep(0.80, 0.97, tableNoise2(float2(p.x * 1.12, p.y * 3.10)));
	float rings = grainA * 0.062 + grainB * 0.026 + (fine - 0.5) * 0.017 - pore * 0.046;
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
