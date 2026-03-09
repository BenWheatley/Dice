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

float tableFbm2(float2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	float amplitudeSum = 0.0;
	for (int octave = 0; octave < 5; ++octave) {
		value += tableNoise2(p * frequency) * amplitude;
		amplitudeSum += amplitude;
		frequency *= 2.03;
		amplitude *= 0.5;
	}
	return amplitudeSum > 0.0 ? (value / amplitudeSum) : 0.0;
}

#pragma body
// Base UV center.
float2 centeredUV = (_surface.diffuseTexcoord - 0.5);
// Procedural felt/wood patterns use per-axis point mapping so texture scale stays stable
// when the view rotates between portrait and landscape.
float2 p = centeredUV * float2(max(tableTextureScaleX, 1.0), max(tableTextureScaleY, 1.0));

float3 color;
if (tableTextureMode < 0.5) {
	// Felt: domain-warped fBm + anisotropic microfibers so the surface reads as fabric, not flat paint.
	float2 feltBase = p * 0.092;
	float warpX = tableNoise2(feltBase * 1.27 + float2(13.1, 5.7)) - 0.5;
	float warpY = tableNoise2(feltBase * 1.91 + float2(4.3, 21.9)) - 0.5;
	float2 feltWarped = feltBase + float2(warpX * 1.35, warpY * 1.10);

	float2 fiberAxisA = normalize(float2(0.94, 0.34));
	float2 fiberAxisB = normalize(float2(-0.29, 0.96));
	float microfiberA = tableFbm2(float2(
		dot(feltWarped, fiberAxisA) * 5.8,
		dot(feltWarped, fiberAxisB) * 1.7 + 7.0
	));
	float microfiberB = tableFbm2(float2(
		dot(feltWarped, fiberAxisB) * 6.6 + 11.0,
		dot(feltWarped, fiberAxisA) * 1.4 - 3.0
	));
	float nap = tableNoise2(feltWarped * 14.5 + float2(3.0, 17.0));
	float lintMask = smoothstep(0.82, 0.98, tableNoise2(feltWarped * 20.0 + float2(29.0, 2.0)));
	float clouding = tableFbm2(feltWarped * 2.2 + float2(19.0, 31.0));

	float fiberContrast = (microfiberA - 0.5) * 0.18 + (microfiberB - 0.5) * 0.14;
	float napContrast = (nap - 0.5) * 0.10;
	float cloudContrast = (clouding - 0.5) * 0.16;

	float3 base = float3(0.11, 0.32, 0.20);
	color = base
		+ float3(0.60, 1.00, 0.72) * fiberContrast
		+ float3(0.45, 0.70, 0.50) * napContrast
		+ float3(0.40, 0.62, 0.45) * cloudContrast
		+ float3(0.09, 0.14, 0.10) * lintMask;
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
