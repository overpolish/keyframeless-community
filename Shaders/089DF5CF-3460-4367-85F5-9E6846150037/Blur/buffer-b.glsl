// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// Uniform-prefix parity with Image.
// #choice label="Mode" options="Gaussian,Defocus,Directional,Zoom,Spin,Tilt Shift" default=0
uniform int uMode;
// #float label="Radius" units="px" min=0 max=300 slidermax=100 default=20
uniform float uRadius;
// #percent label="Strength" min=0 max=100 default=20
uniform float uStrength;
// #choice label="Aperture" options="Circle,Hexagon,Octagon" default=0
uniform int uAperture;
// #choice label="Quality" options="Draft,Standard,High" default=1
uniform int uQuality;
// #choice label="Edges" options="Clamp,Mirror,Repeat" default=1
uniform int uEdges;
// #point label="Center" default="0.5,0.5"
uniform vec2 uCenter;
// #angle label="Direction" default=0
uniform float uDirection;
// #percent label="Focus Width" min=0 max=100 default=25
uniform float uFocusWidth;
// #percent label="Feather" min=0 max=100 default=15
uniform float uFeather;
// #percent label="Mix" min=0 max=100 default=100
uniform float uMix;

vec2 blurMirrorUV(vec2 uv)
{
	return 1.0 - abs(mod(uv, 2.0) - 1.0);
}

vec2 blurResolveUV(vec2 uv)
{
	if (uEdges == 1) return blurMirrorUV(uv);
	if (uEdges == 2) return fract(uv);
	return clamp(uv, 0.0, 1.0);
}

float blurTiltAmount(vec2 pixelPosition)
{
	vec2 lineDirection = vec2(cos(uDirection), sin(uDirection));
	vec2 lineNormal = vec2(-lineDirection.y, lineDirection.x);
	float distanceFromLine = abs(dot(pixelPosition - uCenter, lineNormal));
	float halfWidth = 0.5 * uFocusWidth * iResolution.y;
	float feather = max(uFeather * iResolution.y, 1.0);
	return smoothstep(halfWidth, halfWidth + feather, distanceFromLine);
}

int blurHalfTaps()
{
	if (uQuality == 0) return 6;
	if (uQuality == 2) return 20;
	return 12;
}

vec4 gaussianPass(sampler2D tex, vec2 uv, vec2 axis, float radius)
{
	int halfTaps = blurHalfTaps();
	vec4 sum = vec4(0.0);
	float weightSum = 0.0;
	for (int i = -20; i <= 20; ++i)
	{
		if (abs(i) > halfTaps) continue;
		float x = float(i) / float(halfTaps);
		float taper = 0.5 + 0.5 * cos(3.14159265 * x);
		float weight = exp(-4.0 * x * x) * taper;
		vec2 sampleUV = blurResolveUV(uv + axis * x * radius / iResolution.xy);
		sum += texture(tex, sampleUV) * weight;
		weightSum += weight;
	}
	return sum / max(weightSum, 0.0001);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float radius = uRadius;
	if (uMode == 5) radius *= blurTiltAmount(fragCoord);
	fragColor = (uMode == 0 || uMode == 5)
		? gaussianPass(iChannel0, fragCoord / iResolution.xy, vec2(1.0, 0.0), radius)
		: texture(iChannel0, fragCoord / iResolution.xy);
}
