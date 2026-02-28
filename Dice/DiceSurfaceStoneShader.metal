float hash13(float3 p) {
    return fract(sin(dot(p, float3(127.1, 311.7, 74.7))) * 43758.5453123);
}

float simplexNoise3D(float3 p) {
    float3 i = floor(p);
    float3 f = fract(p);
    float3 u = f * f * (3.0 - 2.0 * f);

    float n000 = hash13(i + float3(0.0, 0.0, 0.0));
    float n100 = hash13(i + float3(1.0, 0.0, 0.0));
    float n010 = hash13(i + float3(0.0, 1.0, 0.0));
    float n110 = hash13(i + float3(1.0, 1.0, 0.0));
    float n001 = hash13(i + float3(0.0, 0.0, 1.0));
    float n101 = hash13(i + float3(1.0, 0.0, 1.0));
    float n011 = hash13(i + float3(0.0, 1.0, 1.0));
    float n111 = hash13(i + float3(1.0, 1.0, 1.0));

    float nx00 = mix(n000, n100, u.x);
    float nx10 = mix(n010, n110, u.x);
    float nx01 = mix(n001, n101, u.x);
    float nx11 = mix(n011, n111, u.x);
    float nxy0 = mix(nx00, nx10, u.y);
float nxy1 = mix(nx01, nx11, u.y);
return mix(nxy0, nxy1, u.z);
}

#pragma body
float fillMask = _surface.roughness;
float outlineMask = _surface.metalness;
// Use hard symbol cutout so marble cannot bleed into glyph interiors.
float symbolMaskFromRoughness = step(0.90, fillMask);
float symbolMaskFromMetalness = step(0.90, outlineMask);
float fillSymbolMask = symbolMaskFromRoughness;
// Keep outline outside the fill so trim never paints over the symbol interior.
float outlineSymbolMask = clamp(symbolMaskFromMetalness - fillSymbolMask, 0.0, 1.0);
float symbolMask = max(fillSymbolMask, outlineSymbolMask);

float dx = dfdx(fillMask);
float dy = dfdy(fillMask);
_surface.normal = normalize(_surface.normal + float3(-dx * 0.95, -dy * 0.95, 0.0));

float baseRoughness = 0.82;
// Fill remains matte paint; outline is opposite-ink trim and roughened to avoid glare blowout.
float fillRoughness = 0.97;
float outlineRoughness = 0.58;
_surface.roughness = baseRoughness;
_surface.roughness = mix(_surface.roughness, fillRoughness, fillSymbolMask);
_surface.roughness = mix(_surface.roughness, outlineRoughness, outlineSymbolMask);
_surface.metalness = outlineSymbolMask * 0.55;

// Convert surface position (view space) back into this die's local model space.
float4 worldPos = scn_frame.inverseViewTransform * float4(_surface.position.xyz, 1.0);
float3 modelPos = (scn_node.inverseModelTransform * worldPos).xyz;

float3 p = modelPos * 0.34;

float n1 = simplexNoise3D(p * 0.28 + float3(1.7, 2.3, 3.1));
float n2 = simplexNoise3D(p * 0.58 + float3(7.3, 5.9, 11.2));
float n3 = simplexNoise3D(p * 0.96 + float3(13.4, 9.1, 4.6));

float swirl = (n1 * 0.62) + (n2 * 0.28) + (n3 * 0.10);

const float3 v = normalize(float3(3.0, 2.0, 1.0));
float d = dot(p, v);

float veins = sin(d * 0.24 + swirl * 3.1);
float veinMask = smoothstep(0.50, 0.965, 0.5 + 0.5 * veins);
float grain = (n1 * 0.56) + (n2 * 0.31) + (n3 * 0.13);
float fleck = smoothstep(0.95, 0.994, simplexNoise3D(p * 1.45 + 19.0));

float3 base = _surface.diffuse.rgb;
float luminance = dot(base, float3(0.2126, 0.7152, 0.0722));
float mainShade = mix(0.74, 1.13, grain);
float3 mainColor = clamp(base * mainShade, 0.0, 1.0);
float3 lightContrast = mix(base, float3(1.0, 1.0, 1.0), 0.72);
float3 darkContrast = base * 0.34;
float3 contrastColor = luminance > 0.52 ? darkContrast : lightContrast;
float marblePattern = clamp(veinMask * 0.78 + fleck * 0.22, 0.0, 1.0);
float3 marble = mix(mainColor, contrastColor, marblePattern);

float3 symbolColor = clamp(_surface.emission.rgb, 0.0, 1.0);
float symbolLuminance = dot(symbolColor, float3(0.2126, 0.7152, 0.0722));
float3 outlineColor = symbolLuminance > 0.5 ? float3(0.0, 0.0, 0.0) : float3(1.0, 1.0, 1.0);
float3 painted = mix(clamp(marble, 0.0, 1.0), symbolColor, fillSymbolMask);
_surface.diffuse.rgb = mix(painted, outlineColor, outlineSymbolMask);
_surface.emission.rgb = float3(0.0);
_surface.specular.rgb *= 0.32;
_surface.shininess = max(_surface.shininess, 0.18);
